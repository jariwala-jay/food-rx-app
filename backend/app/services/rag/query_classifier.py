"""
rag/query_classifier.py — query classification, polite-chat detection,
session-closing detection, and history-to-contents conversion.
"""

from __future__ import annotations

import logging
import re
import unicodedata
from typing import Any

from google.genai import types

from app.services.rag.constants import (
    _DIET_SIGNALS,
    _EMERGENCY_PATTERNS,
    _EXERCISE_INTENT,
    _HARD_MEDICAL_PATTERNS,
    _HOW_ARE_YOU_NOTE,
    _INJECTION_PATTERNS,
    _OFFTOPIC_PATTERNS,
    _POLITE_CHAT_NOTE,
    _SOFT_MEDICAL_PATTERNS,
    _UNSUPPORTED_CONDITION_PATTERNS,
    MAX_HISTORY,
)
from app.services.rag.security import (
    _looks_like_food_drug_interaction_query,
    _looks_like_medication_decision_query,
)
from app.services.rag.profile_helpers import _infer_kb_categories

logger = logging.getLogger(__name__)


class _QueryClass:
    EMERGENCY = "emergency"
    MEDICAL = "medical"
    OFF_TOPIC = "off_topic"
    DIET = "diet"


# ---------------------------------------------------------------------------
# Local pattern constants used only by this module
# ---------------------------------------------------------------------------

# After _normalize_chat_line(), exact match only (no extra words).
_POLITE_CHAT_EXACT = frozenset(
    {
        "hi",
        "hello",
        "hey",
        "yo",
        "hiya",
        "howdy",
        "hi there",
        "hello there",
        "hey there",
        "thanks",
        "thank you",
        "thankyou",
        "thx",
        "ty",
        "thnx",
        "thank u",
        "thank you so much",
        "thanks so much",
        "thank you very much",
        "thanks very much",
        "thanks a lot",
        "many thanks",
        "good morning",
        "good afternoon",
        "good evening",
        "good day",
        "greetings",
        "morning",
        "evening",
        "goodbye",
        "bye",
        "good bye",
        "see you",
        "see you later",
        "see you soon",
        "no more questions",
        "i have no more questions",
        "thats all",
        "that's all",
        "nothing else",
        "nothing else thanks",
        "nothing else thank you",
        "all set",
        "im good",
        "i'm good",
        "no thanks",
        "talk soon",
        "talk later",
        "how are you",
        "how are you doing",
        "how is it going",
        "how's it going",
        "hows it going",
        "hi how are you",
        "hello how are you",
        "hey how are you",
        "good morning how are you",
        "good afternoon how are you",
        "good evening how are you",
    }
)

_POLITE_CHAT_REGEX = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"^(thank you|thanks|thx|ty|thnx|thank u)(\s+(so|very)\s+much)?$",
        r"^(no|nothing)\s+(more|else)(\s+thanks?|\s+thank you)?$",
        r"^i\s*(have|'ve)\s+no\s+more\s+questions$",
        r"^that\s*'?s\s+all(\s+i\s+needed)?(\s+thanks?|\s+thank you|\s+thx|\s+ty)?$",
        r"^how\s+are\s+you(\s+doing)?$",
        r"^(hi|hello|hey|good\s+(morning|afternoon|evening))\s+how\s+are\s+you(\s+doing)?$",
        r"^how'?s\s+it\s+going$",
        r"^(good\s*)?bye[\s!.]*$",
        r"^see\s+ya[\s!.]*$",
        r"^have\s+a\s+good\s+(day|one)[\s!.]*$",
    )
)

# Closing-only — must NOT match greetings ("hi", "how are you") or the router
# mis-fires session_closing and strips follow-up chips.
_SESSION_CLOSING_EXACT = frozenset(
    {
        "ok thanks",
        "ok thank you",
        "okay thanks",
        "okay thank you",
        "thanks",
        "thank you",
        "thankyou",
        "thx",
        "ty",
        "thnx",
        "thank u",
        "thank you so much",
        "thanks so much",
        "thank you very much",
        "thanks very much",
        "thanks a lot",
        "many thanks",
        "goodbye",
        "bye",
        "good bye",
        "see you",
        "see you later",
        "see you soon",
        "no more questions",
        "i have no more questions",
        "thats all",
        "that's all",
        "nothing else",
        "nothing else thanks",
        "nothing else thank you",
        "all set",
        "im good",
        "i'm good",
        "no thanks",
        "talk soon",
        "talk later",
    }
)

_SESSION_CLOSING_REGEX = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"^(ok|okay)\s+(thanks?|thank you)(\s+(so|very)\s+much)?$",
        r"^(thank you|thanks|thx|ty|thnx|thank u)(\s+(so|very)\s+much)?$",
        r"^(no|nothing)\s+(more|else)(\s+thanks?|\s+thank you)?$",
        r"^i\s*(have|'ve)\s+no\s+more\s+questions$",
        r"^that\s*'?s\s+all(\s+i\s+needed)?(\s+thanks?|\s+thank you|\s+thx|\s+ty)?$",
        r"^(good\s*)?bye[\s!.]*$",
        r"^see\s+ya[\s!.]*$",
        r"^have\s+a\s+good\s+(day|one)[\s!.]*$",
    )
)

_HOW_ARE_YOU_EXACT = frozenset(
    {
        "how are you",
        "how are you doing",
        "how is it going",
        "how's it going",
        "hows it going",
    }
)

_OVER_RESTRICTIVE_SCOPE_REPLY = re.compile(
    r"(only\s+help\s+with\s+food|cannot\s+give\s+advice\s+on\s+exercise|cannot\s+tell\s+you\s+how\s+much\s+sleep)",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Public + semi-public functions
# ---------------------------------------------------------------------------


def _normalize_chat_line(message: str) -> str:
    """Normalize user text for matching short greetings/thanks/goodbyes (NBSP, smart quotes)."""
    t = unicodedata.normalize("NFKC", message.strip())
    t = (
        t.replace("\u2018", "'")
        .replace("\u2019", "'")
        .replace("\u201c", '"')
        .replace("\u201d", '"')
        .replace("\xa0", " ")
    )
    while len(t) >= 2 and t[0] == t[-1] and t[0] in "'\"":
        t = t[1:-1].strip()
    t = t.lower()
    # Keep apostrophes for "that's", "i'm"; strip other punctuation to spaces.
    t = re.sub(r'[\s!.,?"…:;–—\-]+', " ", t)
    return re.sub(r"\s+", " ", t).strip()


def _is_how_are_you_turn(message: str) -> bool:
    if _DIET_SIGNALS.search(message):
        return False
    return _normalize_chat_line(message) in _HOW_ARE_YOU_EXACT


def _is_exercise_intent(message: str) -> bool:
    return bool(_EXERCISE_INTENT.search(message))


def _rewrite_lifestyle_scope_refusal(message: str, reply: str) -> str:
    """
    Replace over-restrictive food-only refusals for allowed lifestyle topics.

    This also fixes stale cached responses created before scope rules were widened.
    """
    text = (reply or "").strip()
    if not text or not _OVER_RESTRICTIVE_SCOPE_REPLY.search(text):
        return reply
    cats = _infer_kb_categories(message) or frozenset()
    if "exercise" in cats:
        return (
            "Safe exercise can start with low-impact options like walking, easy cycling, "
            "or chair exercises.\n\n"
            "Start with short sessions, go slow, and stop if you feel pain, dizziness, or chest symptoms.\n\n"
            "If you have a medical condition, ask your doctor before starting a new workout plan."
        )
    if "sleep" in cats:
        return (
            "Most adults need about 7 to 9 hours of sleep each night.\n\n"
            "Try a regular sleep schedule, avoid caffeine late in the day, and keep your room dark and quiet.\n\n"
            "If sleep problems continue for weeks, talk with your doctor."
        )
    return reply


def _skip_rag_polite_chat(message: str) -> bool:
    """True for short greetings/thanks/goodbyes — skip embedding (very short strings often fail)."""
    if _DIET_SIGNALS.search(message):
        return False
    normalized = _normalize_chat_line(message)
    if not normalized:
        return False
    if normalized in _POLITE_CHAT_EXACT:
        return True
    return any(rx.fullmatch(normalized) for rx in _POLITE_CHAT_REGEX)


def is_polite_chat_turn(message: str) -> bool:
    """True for greeting/thanks/goodbye turns — chat router uses this for starter chips."""
    return _skip_rag_polite_chat(message)


def is_session_closing(message: str) -> bool:
    """
    True when the user is clearly ending the chat (thanks, bye, that's all, …).

    Not the same as polite-chat / RAG-skip: greetings and "how are you?" are False here.
    """
    if _DIET_SIGNALS.search(message):
        return False
    normalized = _normalize_chat_line(message)
    if not normalized:
        return False
    if normalized in _SESSION_CLOSING_EXACT:
        return True
    return any(rx.fullmatch(normalized) for rx in _SESSION_CLOSING_REGEX)


def _history_to_contents(history: list[dict[str, Any]]) -> list[types.Content]:
    history_contents: list[types.Content] = []
    for turn in history[-(MAX_HISTORY * 2) :]:
        role = turn.get("role") or "user"
        parts_raw = turn.get("parts") or []
        texts = [p for p in parts_raw if isinstance(p, str) and p.strip()]
        if not texts:
            continue
        history_contents.append(
            types.Content(
                role=role,
                parts=[types.Part(text=p) for p in texts],
            )
        )
    return history_contents


def classify_query(message: str) -> str:
    if _EMERGENCY_PATTERNS.search(message):
        return _QueryClass.EMERGENCY

    if _INJECTION_PATTERNS.search(message):
        logger.warning("Potential prompt injection attempt detected: %.100s", message)
        return _QueryClass.OFF_TOPIC

    if _looks_like_food_drug_interaction_query(message):
        return _QueryClass.DIET

    if _looks_like_medication_decision_query(message):
        return _QueryClass.MEDICAL

    if _HARD_MEDICAL_PATTERNS.search(message):
        return _QueryClass.MEDICAL
    if _UNSUPPORTED_CONDITION_PATTERNS.search(message):
        # Scope guard: only diabetes/prediabetes/hypertension/obesity are supported.
        return _QueryClass.MEDICAL

    has_diet = bool(_DIET_SIGNALS.search(message))

    if _SOFT_MEDICAL_PATTERNS.search(message):
        return _QueryClass.DIET if has_diet else _QueryClass.MEDICAL
    if _OFFTOPIC_PATTERNS.search(message):
        return _QueryClass.DIET if has_diet else _QueryClass.OFF_TOPIC

    return _QueryClass.DIET
