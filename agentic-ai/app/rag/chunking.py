from dataclasses import dataclass

#: One chunk per section rather than per medicine, so retrieval can distinguish "what is it for"
#: from "what are the side effects" instead of always returning the whole entry.
SECTIONS = ("uses", "side_effects", "warnings")


@dataclass(frozen=True)
class Chunk:
    id: str
    medicine_name: str
    section: str
    text: str


def chunk_medicine(entry: dict) -> list[Chunk]:
    name = entry["name"]
    chunks = []
    for section in SECTIONS:
        text = entry.get(section)
        if text:
            chunks.append(Chunk(id=f"{name.lower()}:{section}", medicine_name=name, section=section, text=text))
    return chunks


def chunk_all(entries: list[dict]) -> list[Chunk]:
    chunks: list[Chunk] = []
    for entry in entries:
        chunks.extend(chunk_medicine(entry))
    return chunks
