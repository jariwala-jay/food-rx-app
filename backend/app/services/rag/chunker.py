"""
rag/chunker.py — vector math, sentence splitting, document chunking,
and ChromaDB fingerprinting.
"""

from __future__ import annotations

import hashlib
import logging
import math
import re
from typing import Any

from app.services.rag.constants import (
    CHUNK_MAX_CHARS,
    CHUNK_OVERLAP_SENTENCES,
    EMBEDDING_MODEL,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Vector math
# ---------------------------------------------------------------------------


def _dot(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def _norm(v: list[float]) -> float:
    return math.sqrt(sum(x * x for x in v))


def _cosine(a: list[float], b: list[float]) -> float:
    denom = _norm(a) * _norm(b)
    return 0.0 if denom == 0 else _dot(a, b) / denom


# ---------------------------------------------------------------------------
# Document chunking
# ---------------------------------------------------------------------------


def _normalize_content(content: Any, *, doc_id: str) -> str:
    """Return a safe string for chunking, with guardrails for malformed docs."""
    if isinstance(content, str):
        return content
    if isinstance(content, (tuple, list)):
        parts = [str(part) for part in content if str(part).strip()]
        logger.warning(
            "Knowledge doc %s has %s content; coercing to string.",
            doc_id,
            type(content).__name__,
        )
        return " ".join(parts)
    raise TypeError(
        f"Knowledge doc '{doc_id}' has unsupported content type: {type(content).__name__}"
    )


def _clean_content(content: str) -> str:
    """Normalize PDF line-wrap artifacts before chunking."""
    # Remove leaked section marker if it appears in content blobs.
    content = content.replace("\n\nCategory: Exercise", "")
    # Join hard-wrapped lines that are likely continuation lines.
    content = re.sub(r"\n(?=[a-z(\"'])", " ", content)
    content = re.sub(r"(?<![.!?])\n(?=[A-Z])", " ", content)
    # Keep explicit paragraph breaks, normalize internal spacing.
    content = re.sub(r"[ \t]+", " ", content)
    return content.strip()


def _split_sentences(text: str) -> list[str]:
    """
    Sentence splitter with lightweight abbreviation protection.
    Keeps behavior deterministic and dependency-free.
    """
    # Protect a few common period abbreviations we use in docs.
    replacements = {
        "U.S.": "U<dot>S<dot>",
        "A1C.": "A1C<dot>",
        "HbA1c.": "HbA1c<dot>",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)

    parts = re.split(r"(?<=[.!?])\s+", text)
    out: list[str] = []
    for part in parts:
        if not part:
            continue
        restored = part
        for src, dst in replacements.items():
            restored = restored.replace(dst, src)
        restored = restored.strip()
        if restored:
            out.append(restored)
    return out


def _chunk_doc(doc: dict[str, str]) -> list[dict[str, str | int]]:
    """Build sentence-aware chunks for one knowledge document."""
    raw_content = _normalize_content(
        doc.get("content"), doc_id=str(doc.get("id", "unknown"))
    )
    clean_text = _clean_content(raw_content)
    sentences = _split_sentences(clean_text)
    if not sentences:
        sentences = [clean_text]

    chunks: list[str] = []
    current: list[str] = []
    current_len = 0

    for sentence in sentences:
        sentence_len = len(sentence) + 1
        if current and current_len + sentence_len > CHUNK_MAX_CHARS:
            chunks.append(" ".join(current).strip())
            current = (
                current[-CHUNK_OVERLAP_SENTENCES:]
                if CHUNK_OVERLAP_SENTENCES > 0
                else []
            )
            current_len = sum(len(s) + 1 for s in current)
        current.append(sentence)
        current_len += sentence_len

    if current:
        chunks.append(" ".join(current).strip())

    total_chunks = len(chunks)
    return [
        {
            "doc_id": doc["id"],
            "title": doc["title"],
            "category": doc["category"],
            "source": doc["source"],
            "chunk_index": i,
            "total_chunks": total_chunks,
            "text": text,
        }
        for i, text in enumerate(chunks)
    ]


def build_chunks(docs: list[dict[str, str]]) -> list[dict[str, str | int]]:
    """Chunk all knowledge documents."""
    all_chunks: list[dict[str, str | int]] = []
    for doc in docs:
        all_chunks.extend(_chunk_doc(doc))
    return all_chunks


def _log_chunk_preview(
    chunks: list[dict[str, str | int]], sample_per_doc: int = 2
) -> None:
    """Log chunk counts and short previews for quick verification."""
    if not chunks:
        logger.info("Chunk preview: no chunks generated.")
        return

    grouped: dict[str, list[dict[str, str | int]]] = {}
    for chunk in chunks:
        doc_id = str(chunk["doc_id"])
        grouped.setdefault(doc_id, []).append(chunk)

    total_docs = len(grouped)
    logger.info(
        "Chunk preview: %d docs -> %d chunks.",
        total_docs,
        len(chunks),
    )
    for doc_id, doc_chunks in grouped.items():
        logger.info("Chunk count: %s -> %d", doc_id, len(doc_chunks))

    for doc_id, doc_chunks in grouped.items():
        logger.debug("Doc %s has %d chunks.", doc_id, len(doc_chunks))
        for chunk in doc_chunks[:sample_per_doc]:
            chunk_index = chunk["chunk_index"]
            total_chunks = chunk["total_chunks"]
            text = str(chunk["text"]).strip().replace("\n", " ")
            snippet = text[:140] + ("..." if len(text) > 140 else "")
            logger.debug(
                "Chunk %s[%s/%s]: %s",
                doc_id,
                int(chunk_index) + 1,
                total_chunks,
                snippet,
            )


# ---------------------------------------------------------------------------
# Fingerprinting (ChromaDB cache invalidation)
# ---------------------------------------------------------------------------


def _chunks_content_sha256(chunks: list[dict[str, str | int]]) -> str:
    """Stable hash of all chunk identities + text — invalidates cache on any KB edit."""
    h = hashlib.sha256()
    for c in chunks:
        h.update(str(c["doc_id"]).encode())
        h.update(b"\0")
        h.update(str(c.get("chunk_index", 0)).encode())
        h.update(b"\0")
        h.update(str(c.get("text", "")).encode())
        h.update(b"\n")
    return h.hexdigest()


def _cache_fingerprint(chunks: list[dict[str, str | int]]) -> dict[str, Any]:
    return {
        "count": len(chunks),
        "chunks_sha256": _chunks_content_sha256(chunks),
        "embedding_model": EMBEDDING_MODEL,
    }
