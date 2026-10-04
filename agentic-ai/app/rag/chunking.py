import hashlib
import re

from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter

#: One Document per section rather than per medicine, so retrieval can distinguish "what is it for"
#: from "what are the side effects" instead of always returning the whole entry.
SECTIONS = ("uses", "side_effects", "warnings")

SOURCE = "knowledge_base.json"

#: The curated sections are a few hundred characters, so in practice the splitter leaves them whole;
#: it only splits if a future entry grows past this size, and every split keeps the section metadata.
_CHUNK_SIZE = 800
_CHUNK_OVERLAP = 100


def medicine_id(name: str) -> str:
    """Knowledge-base identity of a medicine. NOT a reference to any user's personal medicine row."""
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def entries_to_documents(entries: list[dict]) -> list[Document]:
    documents = []
    for entry in entries:
        for section in SECTIONS:
            text = entry.get(section)
            if text:
                documents.append(
                    Document(
                        page_content=text,
                        metadata={
                            "medicine_id": medicine_id(entry["name"]),
                            "medicine_name": entry["name"],
                            "section": section,
                            "source": SOURCE,
                        },
                    )
                )
    return documents


def split_documents(documents: list[Document], embedding_model: str) -> list[Document]:
    """Split, then give every chunk a stable id and a content hash.

    The id is deterministic (`medicine:section:index`), so re-ingesting upserts instead of
    duplicating. The hash covers the text *and* the embedding model, so a changed chunk or a
    changed model is detected and re-embedded, while an unchanged one is skipped."""
    splitter = RecursiveCharacterTextSplitter(chunk_size=_CHUNK_SIZE, chunk_overlap=_CHUNK_OVERLAP)
    chunks: list[Document] = []
    for document in documents:
        parts = splitter.split_documents([document])
        for index, part in enumerate(parts):
            chunk_id = f"{part.metadata['medicine_id']}:{part.metadata['section']}:{index}"
            part.id = chunk_id
            part.metadata = {
                **part.metadata,
                "chunk_index": index,
                "chunk_id": chunk_id,
                "content_hash": hashlib.sha256(f"{embedding_model}\n{part.page_content}".encode()).hexdigest(),
            }
            chunks.append(part)
    return chunks
