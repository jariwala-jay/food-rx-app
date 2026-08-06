"""
rag/response_helpers.py — LLM response parsing, phrase stripping, and
follow-up suggestion gating.
"""

from __future__ import annotations

import logging
import re
from typing import Any

from app.services.rag.constants import _NO_FOLLOWUP_PREFIXES

logger = logging.getLogger(__name__)

# Whole-line or inline echoes of legacy UI copy (do not swallow paragraph breaks).
_EXPLORE_MORE_BELOW_LINE = re.compile(
    r"^\s*\*?\s*you can explore more below[\.\!…]*\*?\s*$",
    re.IGNORECASE | re.MULTILINE,
)
_EXPLORE_MORE_BELOW_INLINE = re.compile(
    r"[ \t\*_]*you can explore more below[\.\!…]*[ \t\*_]*",
    re.IGNORECASE,
)


def should_suggest_follow_ups(answer: str) -> bool:
    """
    Skip follow-up question generation for canned guardrails, errors, and very short replies.
    """
    t = (answer or "").strip()
    if len(t) < 24:
        return False
    return not any(t.startswith(p) for p in _NO_FOLLOWUP_PREFIXES)


def _strip_llm_ui_phrases(text: str) -> str:
    """Remove UI-only phrases that must not appear in assistant replies."""
    t = (text or "").strip()
    t = _EXPLORE_MORE_BELOW_LINE.sub("", t)
    t = _EXPLORE_MORE_BELOW_INLINE.sub("", t)
    # Normalize a few common model quirks before the user sees them.
    t = re.sub(r"\bDiabetesPlate\b", "Diabetes Plate", t)
    t = re.sub(
        r"(?i)\byou want foods that help\b",
        "These foods help",
        t,
    )
    t = re.sub(
        r"(?i)\bthe diabetes plate helps you do this\b",
        "The Diabetes Plate is a simple way to plan this",
        t,
    )
    t = re.sub(
        r"(?i)\bdiabetes plate helps you do this\b",
        "The Diabetes Plate is a simple way to plan this",
        t,
    )
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


def _extract_text_from_generate_response(response: Any) -> str:
    """
    Aggregate assistant text from all candidates and parts.

    ``response.text`` alone can miss text when the model returns multiple
    ``parts`` (e.g. thinking models: skip ``part.thought`` reasoning blocks).
    """
    chunks: list[str] = []
    try:
        for candidate in getattr(response, "candidates", None) or []:
            content = getattr(candidate, "content", None)
            if content is None:
                continue
            for part in getattr(content, "parts", None) or []:
                # User-visible answer text only; skip internal reasoning parts.
                if getattr(part, "thought", None) is True:
                    continue
                t = getattr(part, "text", None)
                if isinstance(t, str) and t:
                    chunks.append(t)
    except Exception as exc:
        logger.debug("Candidate parts text walk failed: %s", exc)
    joined = "".join(chunks).strip()
    if joined:
        return joined
    fallback = getattr(response, "text", None)
    return (fallback or "").strip() if isinstance(fallback, str) else ""


def _is_truncation_finish_reason(finish_reason: Any) -> bool:
    """True when the model stopped because of an output length/token cap (unsafe to cache)."""
    fr = str(finish_reason) if finish_reason is not None else ""
    u = fr.upper()
    return "MAX" in u or "LENGTH" in u or "TOKEN" in u


def _log_gemini_generation_usage(
    usage_metadata: Any | None, model_name: str | None = None
) -> None:
    """Backend-only token logging; never attach to API responses."""
    if not usage_metadata:
        return
    um = usage_metadata
    thoughts = getattr(um, "thoughts_token_count", None)
    if thoughts:
        logger.info(
            "Tokens (model=%s) → input: %s, output: %s, thoughts: %s, total: %s",
            model_name or "?",
            getattr(um, "prompt_token_count", None),
            getattr(um, "candidates_token_count", None),
            thoughts,
            getattr(um, "total_token_count", None),
        )
    else:
        logger.info(
            "Tokens (model=%s) → input: %s, output: %s, total: %s",
            model_name or "?",
            getattr(um, "prompt_token_count", None),
            getattr(um, "candidates_token_count", None),
            getattr(um, "total_token_count", None),
        )
