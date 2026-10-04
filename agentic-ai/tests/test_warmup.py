import asyncio
import logging
import threading
import time

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_medicine_knowledge_retriever
from app.main import app
from app.rag.ingest import build_name_lookup, ingest_knowledge_base
from app.rag.retriever import MedicineKnowledgeRetriever, RagUnavailableError
from app.rag.warmup import warm_up_knowledge_base
from tests.fakes import ENTRIES, KeywordFakeEmbeddings, make_store


def _retriever(factory) -> MedicineKnowledgeRetriever:
    return MedicineKnowledgeRetriever(build_name_lookup(ENTRIES), factory)


def _good_factory():
    store = make_store(KeywordFakeEmbeddings())
    ingest_knowledge_base(store, ENTRIES, "test-model")
    return store


def test_warm_up_initialises_the_store_so_the_first_question_does_not() -> None:
    calls = []

    def factory():
        calls.append(1)
        return _good_factory()

    retriever = _retriever(factory)
    assert retriever.status == "pending" and calls == []

    asyncio.run(warm_up_knowledge_base(retriever, timeout_seconds=5))
    assert retriever.status == "ready" and len(calls) == 1

    # The first real question reuses the warmed store: no second connect/sync.
    assert retriever.retrieve("side effects of metformin", "Metformin", top_k=1)
    assert len(calls) == 1


def test_warm_up_failure_is_contained_logged_safely_and_retried_by_the_first_question(caplog) -> None:
    attempts = []

    def factory():
        attempts.append(1)
        if len(attempts) == 1:
            raise RuntimeError("could not connect to postgresql://user:SUPERSECRET@host")
        return _good_factory()

    retriever = _retriever(factory)
    with caplog.at_level(logging.INFO):
        asyncio.run(warm_up_knowledge_base(retriever, timeout_seconds=5))  # must not raise

    assert retriever.status == "failed"
    assert "SUPERSECRET" not in caplog.text and "postgresql://" not in caplog.text
    assert "warm-up failed" in caplog.text

    # Existing lazy behaviour is the fallback: the next question retries and succeeds.
    assert retriever.retrieve("side effects of metformin", "Metformin", top_k=1)
    assert retriever.status == "ready" and len(attempts) == 2


def test_warm_up_does_not_block_beyond_its_timeout(caplog) -> None:
    release = threading.Event()

    def slow_factory():
        release.wait(5)
        return _good_factory()

    retriever = _retriever(slow_factory)
    elapsed = []

    async def timed() -> None:
        started = time.monotonic()
        await warm_up_knowledge_base(retriever, timeout_seconds=0.2)
        elapsed.append(time.monotonic() - started)
        release.set()  # let the worker finish so the loop can close promptly

    with caplog.at_level(logging.INFO):
        try:
            asyncio.run(timed())
        finally:
            release.set()
    elapsed = elapsed[0]

    assert elapsed < 2
    assert "still running" in caplog.text


def test_warm_up_and_a_concurrent_question_share_a_single_initialisation() -> None:
    calls = []
    gate = threading.Event()

    def factory():
        calls.append(1)
        gate.wait(2)
        return _good_factory()

    retriever = _retriever(factory)
    threads = [threading.Thread(target=retriever.warm_up), threading.Thread(target=lambda: retriever.retrieve("q", "Metformin"))]
    for t in threads:
        t.start()
    time.sleep(0.2)
    gate.set()
    for t in threads:
        t.join()

    assert len(calls) == 1 and retriever.status == "ready"


def test_a_failed_warm_up_surfaces_as_rag_unavailable_not_a_crash() -> None:
    retriever = _retriever(lambda: (_ for _ in ()).throw(RuntimeError("down")))
    with pytest.raises(RagUnavailableError):
        retriever.warm_up()


def test_service_starts_and_reports_status_even_when_warm_up_fails(monkeypatch) -> None:
    from app.config import get_settings

    failing = _retriever(lambda: (_ for _ in ()).throw(RuntimeError("db down")))
    monkeypatch.setenv("WARM_UP_ON_STARTUP", "true")
    get_settings.cache_clear()
    app.dependency_overrides[get_medicine_knowledge_retriever] = lambda: failing
    monkeypatch.setattr("app.main.get_medicine_knowledge_retriever", lambda settings: failing)
    try:
        with TestClient(app) as client:  # runs the lifespan (startup warm-up) and must not fail
            deadline = time.monotonic() + 3
            while failing.status == "pending" and time.monotonic() < deadline:
                time.sleep(0.05)
            body = client.get("/health").json()
        assert body["status"] == "ok"
    finally:
        monkeypatch.setenv("WARM_UP_ON_STARTUP", "false")
        get_settings.cache_clear()
        app.dependency_overrides.pop(get_medicine_knowledge_retriever, None)
