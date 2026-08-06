"""
rag/profile_helpers.py — user profile resolution, KB category mapping,
multi-condition overlay building, and query-expansion helpers.

Note: _infer_kb_categories lives here (not in query_classifier) to avoid
a circular import between query_classifier ↔ profile_helpers.
"""

from __future__ import annotations

import re
from typing import Any

from app.services.rag.constants import (
    _DIET_SIGNALS,
    _EXERCISE_INTENT,
    _FOLLOWUP_QUERY_PATTERN,
    MAX_HISTORY,
)


def _resolve_plan_for_profile(user_profile: dict[str, Any] | None) -> str | None:
    """Resolve chatbot plan key: diabetes override, then myPlanType, then condition inference."""
    if not isinstance(user_profile, dict):
        return None

    conditions = (
        user_profile.get("medicalConditions") or user_profile.get("conditions") or []
    )
    if isinstance(conditions, str):
        conditions = [conditions]
    normalized = [str(c).lower() for c in conditions]
    if any("prediabetes" in c or "diabetes" in c for c in normalized):
        return "DiabetesPlate"

    raw_plan = user_profile.get("myPlanType")
    if raw_plan:
        plan_text = str(raw_plan).strip().lower().replace("-", " ")
        compact = plan_text.replace(" ", "")
        if compact in {"diabetesplate", "diabetes"} or "diabetes plate" in plan_text:
            return "DiabetesPlate"
        if compact in {"dash", "dashdiet"} or "dash" in plan_text:
            return "DASH"
        if (
            compact in {"myplate", "plate"}
            or "myplate" in plan_text
            or "my plate" in plan_text
        ):
            return "MyPlate"

    if any("hypertension" in c or "blood pressure" in c for c in normalized):
        return "DASH"
    return "MyPlate"


def _profile_kb_categories(user_profile: dict[str, Any] | None) -> frozenset[str]:
    """Map profile medical conditions to food_knowledge chunk category keys."""
    if not isinstance(user_profile, dict):
        return frozenset()
    conditions = (
        user_profile.get("medicalConditions")
        or user_profile.get("conditions")
        or []
    )
    if isinstance(conditions, str):
        conditions = [conditions]
    cats: set[str] = set()
    for c in conditions:
        t = str(c).lower()
        if "prediabetes" in t or "pre-diabetes" in t or "diabetes" in t:
            cats.add("diabetes")
        if "hypertension" in t or "blood pressure" in t:
            cats.add("hypertension")
        if "obesity" in t or "overweight" in t:
            cats.add("obesity")
    return frozenset(cats)


def _build_multi_condition_note(user_profile: dict[str, Any] | None) -> str | None:
    """Blend instructions for users with 2+ conditions — injected near the question in RAG payload."""
    if not isinstance(user_profile, dict):
        return None
    conditions = (
        user_profile.get("medicalConditions")
        or user_profile.get("conditions")
        or []
    )
    if isinstance(conditions, str):
        conditions = [conditions]
    condition_flags: dict[str, bool] = {
        "diabetes": False,
        "hypertension": False,
        "obesity": False,
    }
    for c in conditions:
        t = str(c).lower()
        if "prediabetes" in t or "pre-diabetes" in t or "diabetes" in t:
            condition_flags["diabetes"] = True
        if "hypertension" in t or "blood pressure" in t:
            condition_flags["hypertension"] = True
        if "obesity" in t or "overweight" in t:
            condition_flags["obesity"] = True

    active = [k for k, v in condition_flags.items() if v]
    if len(active) < 2:
        return None

    overlays: list[str] = []
    if condition_flags["diabetes"] and condition_flags["hypertension"]:
        overlays.append(
            "Use Diabetes Plate structure. Also apply low-sodium choices — "
            "avoid processed meats, canned soups, and high-salt foods. "
            "When a food helps blood sugar but is high in sodium, say so briefly."
        )
    if condition_flags["diabetes"] and condition_flags["obesity"]:
        overlays.append(
            "Use Diabetes Plate structure. Keep portion sizes moderate — "
            "note calorie density where relevant without turning every answer into calorie math."
        )
    if condition_flags["hypertension"] and condition_flags["obesity"]:
        overlays.append(
            "Use DASH structure. Keep portions moderate alongside sodium guidance."
        )
    if not overlays:
        return None

    blending = (
        "Give one practical blended answer — not separate sections per condition. "
        "Name foods that satisfy both constraints together when possible. "
        "When a food helps one condition but conflicts with another, say so in one plain sentence."
    )
    return "\n".join(overlays + [blending])


def _is_followup_query(message: str) -> bool:
    return bool(_FOLLOWUP_QUERY_PATTERN.search(message))


def _infer_kb_categories(message: str) -> frozenset[str] | None:
    """
    Map user wording to food_knowledge chunk categories (lowercased).
    Used to restrict retrieval when global cosine similarity is often too low
    for lifestyle questions.
    """
    lc = message.lower()
    cats: set[str] = set()
    if re.search(
        r"\b("
        r"sleep|sleeping|insomnia|bedtime|nap\b|lack of sleep|sleep deprivation|"
        r"sleep-deprived|sleep deprived|poor sleep|sleep loss|not enough sleep|"
        r"melatonin|tryptophan|circadian|"
        r"can'?t sleep|restful|sleep quality"
        r")\b",
        lc,
    ):
        cats.add("sleep")
    if _EXERCISE_INTENT.search(message):
        cats.add("exercise")
    if re.search(
        r"\b("
        r"water|hydrat|fluid|dehydrat|thirst|ounces|\bliters?\b|"
        r"drink\s+when|when\s+exercising|while\s+exercising|during\s+exercise|"
        r"how\s+much\s+.*\s+drink"
        r")\b",
        lc,
    ):
        cats.add("hydration")
    if re.search(
        r"\b("
        r"blood\s*pressure|hypertension|\bhbp\b|\bsalt\b|sodium|"
        r"dash\s+diet|dash\b"
        r")\b",
        lc,
    ):
        cats.add("hypertension")
    if re.search(
        r"\b(prediabetes|pre-diabetes|prediabetic|borderline\s+diabetes)\b",
        lc,
    ):
        cats.add("pre-diabetes")
    if re.search(
        r"\b("
        r"diabetes|type\s*1|type\s*2|blood\s*sugar|glucose|a1c|hba1c|"
        r"insulin|carb(ohydrate)?|glycemic|plate method|diabetes plate"
        r")\b",
        lc,
    ):
        cats.add("diabetes")
    if re.search(r"\b(obesity|overweight|weight\s+loss|lose\s+weight|\bbmi\b)\b", lc):
        cats.add("obesity")
    if not cats:
        return None
    return frozenset(cats)


def _infer_kb_categories_from_history(
    history: list[dict[str, Any]],
) -> frozenset[str]:
    """Merge KB categories from recent user turns — for vague follow-up queries."""
    cats: set[str] = set()
    for turn in reversed(history[-(MAX_HISTORY * 2) :]):
        if turn.get("role") != "user":
            continue
        for part in turn.get("parts") or []:
            if isinstance(part, str) and part.strip():
                inferred = _infer_kb_categories(part)
                if inferred:
                    cats.update(inferred)
    return frozenset(cats)


def _should_apply_multi_condition_overlay(
    message: str,
    topic_cats: frozenset[str] | None,
) -> bool:
    """
    Apply multi-condition overlay only for general food/meal queries.
    Skip when the user named a specific condition topic or is following up on one.
    """
    msg_lower = message.lower()

    explicit_condition = re.search(
        r"\b(pre-?diabetes|prediabetes|blood pressure|hypertension|"
        r"diabetes|blood sugar|obesity|weight loss)\b",
        msg_lower,
    )
    if explicit_condition:
        return False

    if _is_followup_query(message):
        return False

    if not _DIET_SIGNALS.search(message):
        return False

    return True


def _embedding_text_for_retrieval(
    message: str,
    user_profile: dict[str, Any] | None = None,
    *,
    is_followup: bool = False,
    history_cats: frozenset[str] | None = None,
) -> str:
    """
    Expand query text with topic keywords for better embedding similarity.
    Also injects profile condition hints so retrieval covers secondary conditions
    even when the query doesn't mention them explicitly.
    """
    query_cats = _infer_kb_categories(message) or frozenset()
    profile_cats = _profile_kb_categories(user_profile)
    if is_followup:
        all_cats = (history_cats or frozenset()) | profile_cats | query_cats
    else:
        all_cats = query_cats | profile_cats

    hints: list[str] = []
    if "sleep" in all_cats:
        hints.append(
            "sleep melatonin tryptophan appetite calories ghrelin leptin diet nutrition "
            "sleep hygiene insomnia blood sugar blood pressure"
        )
    if "exercise" in all_cats:
        hints.append(
            "physical activity aerobic strength exercise safety blood pressure diabetes"
        )
    if "hydration" in all_cats:
        hints.append("water fluid hydration dehydration exercise sweating")
    if "hypertension" in all_cats:
        hints.append("blood pressure hypertension DASH sodium exercise safety")
    if "pre-diabetes" in all_cats or "prediabetes" in all_cats:
        hints.append("prediabetes blood sugar insulin resistance diet")
    if "diabetes" in all_cats:
        hints.append("diabetes blood glucose insulin carbohydrate glycemic")
    if "obesity" in all_cats:
        hints.append("obesity weight management calories diet exercise")

    if not hints:
        return message
    topic_suffix = "\n\nTopic keywords: " + " ".join(hints)
    combined = message + topic_suffix
    # Cap at 500 chars — embedding API can reject very long strings silently.
    if len(combined) > 500:
        max_hints = 500 - len(message) - len("\n\nTopic keywords: ")
        hints_text = " ".join(hints)[: max(0, max_hints)]
        return message + "\n\nTopic keywords: " + hints_text
    return combined
