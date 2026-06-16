"""
question_banks.py — static question data and condition-aware helpers.

Contains:
  - STARTER_QUESTION_POOLS   (plan-keyed pools, 18-19 each, shuffled to pick 5)
  - QUESTION_BANK            (follow-up chip data, keyed by condition/plan/topic)
  - COMBINATION_QUESTION_BANK (pair and triple condition follow-up banks)
  - generate_starter_questions()
  - Condition-extraction and plan-resolution helpers

Nothing here does I/O, calls the DB, or imports from FastAPI.
Reading level target: 2nd–3rd grade for all question text.
"""

from __future__ import annotations

import random
import re
from typing import Any

# ---------------------------------------------------------------------------
# Condition text helpers
# ---------------------------------------------------------------------------


def _normalize_condition_text(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def _extract_profile_conditions(user_profile: dict[str, Any] | None) -> list[str]:
    """
    Pull condition list from profile.
    Prefer explicit ``conditions`` field, then ``medicalConditions``.
    """
    if not isinstance(user_profile, dict):
        return []

    raw = user_profile.get("conditions")
    if raw is None:
        raw = user_profile.get("medicalConditions")

    if isinstance(raw, str):
        raw_items = [raw]
    elif isinstance(raw, list):
        raw_items = raw
    else:
        return []

    seen: set[str] = set()
    out: list[str] = []
    for item in raw_items:
        text = _normalize_condition_text(item)
        if not text:
            continue
        key = text.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(text)
    return out


def format_conditions(conditions: list[str]) -> str:
    """Human-readable condition phrase used in starter question templates."""
    clean = [
        _normalize_condition_text(c) for c in conditions if _normalize_condition_text(c)
    ]
    if not clean:
        return "my condition"
    if len(clean) == 1:
        return clean[0]
    if len(clean) == 2:
        return f"{clean[0]} and {clean[1]}"
    return ", ".join(clean[:-1]) + f", and {clean[-1]}"


# ---------------------------------------------------------------------------
# Plan resolver (lightweight copy — avoids circular import with rag_service)
#
# Priority matches _resolve_plan_for_profile() in rag_service.py exactly:
#   1. diabetes/prediabetes in conditions  → DiabetesPlate  (always overrides)
#   2. myPlanType field (normalised)       → DiabetesPlate / DASH / MyPlate
#   3. hypertension in conditions          → DASH
#   4. default                             → MyPlate
# ---------------------------------------------------------------------------


def _resolve_starter_plan(user_profile: dict[str, Any] | None) -> str:
    """
    Resolve the plan key used to select the starter question pool.
    Returns one of: 'PreDiabetes', 'DiabetesPlate', 'DASH', 'MyPlate'.

    Prediabetes-only users get the prevention-framed PreDiabetes pool.
    Full diabetes (or diabetes + prediabetes together) gets DiabetesPlate.
    """
    if not isinstance(user_profile, dict):
        return "MyPlate"

    conditions = (
        user_profile.get("medicalConditions") or user_profile.get("conditions") or []
    )
    if isinstance(conditions, str):
        conditions = [conditions]
    normalized = [str(c).lower() for c in conditions]

    has_prediabetes = any(
        "prediabetes" in c or "pre-diabetes" in c for c in normalized
    )
    has_full_diabetes = any(
        "diabetes" in c and "prediabetes" not in c and "pre-diabetes" not in c
        for c in normalized
    )

    # Full diabetes overrides everything — use structured plate approach.
    if has_full_diabetes:
        return "DiabetesPlate"

    # Prediabetes-only → prevention-framed pool.
    if has_prediabetes:
        return "PreDiabetes"

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


# ---------------------------------------------------------------------------
# Starter question pools  (18-19 per plan → picks 5 each session)
#
# Design rules:
#   - 2nd–3rd grade reading level throughout
#   - Each pool: ~6 food/plan questions + 2 condition-specific + 1 grocery
#     + lifestyle questions (exercise, hydration, sleep)
# ---------------------------------------------------------------------------

STARTER_QUESTION_POOLS: dict[str, list[str]] = {
    "DiabetesPlate": [
        # food / plan
        "What foods help keep my blood sugar steady?",
        "Can you suggest simple meals that are easy on blood sugar?",
        "What should I eat for breakfast with diabetes?",
        "Can you show a Diabetes Plate meal example?",
        "How do I divide my plate for blood sugar control?",
        "What does a healthy day of eating look like for diabetes?",
        # condition-specific
        "Can I eat rice or bread with diabetes?",
        "Which fruits have the least impact on blood sugar?",
        # grocery
        "What should go on my grocery list this week?",
        # snacks
        "What snacks are good for managing my blood sugar?",
        # food label
        "How do I check a food label for sugar?",
        # hunger
        "What should I eat if I feel hungry between meals?",
        # dinner
        "What are easy dinner ideas for diabetes?",
        # exercise
        "How can I stay active during the day?",
        "How does staying active through the day help with diabetes?",
        # hydration
        "How much water should I drink daily?",
        # sleep
        "How many hours should I sleep each night?",
        "How does poor sleep affect my blood sugar?",
    ],
    "DASH": [
        # food / plan
        "What are some naturally low-sodium meal ideas?",
        "Can you suggest simple DASH-style meals?",
        "Can you show a DASH-style daily meal plan?",
        "What foods are low in sodium?",
        "What is a simple heart-healthy breakfast idea?",
        "Which fruits and vegetables are good for blood pressure?",
        # condition-specific
        "What should I look for when eating out to keep sodium low?",
        # snacks
        "What are low-sodium snack options?",
        "What are some satisfying, lower-sodium snack swaps?",
        # grocery / labels
        "What should I look for on food labels?",
        # cooking
        "How do I cook without adding too much salt?",
        "What spices can I use instead of salt?",
        # exercise
        "How can I stay active during the day?",
        "What type of exercise is best for heart health?",
        "What is the best time of day to exercise for blood pressure?",
        # hydration
        "How much water should I drink daily?",
        "What drinks help or hurt my blood pressure?",
        # sleep
        "How many hours should I sleep each night?",
    ],
    "MyPlate": [
        # food / plan
        "Can you show a balanced MyPlate meal?",
        "How do I build a healthy plate?",
        "How do I balance grains, protein, and vegetables?",
        "What does a balanced dinner look like?",
        "What is a quick healthy meal I can make in 20 minutes?",
        "What is a quick healthy meal I can make tonight?",
        # snacks
        "What are healthy snack options?",
        "What can I eat between meals?",
        # grocery / pantry
        "What foods should I buy for balanced meals?",
        "What are 5 foods I should always have at home?",
        # habits / portions
        "What is one eating habit I can start this week?",
        "How do I control my portion sizes?",
        # budget
        "How do I eat healthy on a budget?",
        # exercise
        "How can I stay active during the day?",
        "What simple activities help me stay active at home?",
        "How do I know if I am drinking enough water each day?",
        # hydration
        "How much water should I drink daily?",
        # sleep
        "How can I improve my sleep quality?",
        "How does better sleep support healthy eating habits?",
    ],
    # Prevention-framed pool for prediabetes-only users.
    # No "Diabetes Plate" references — goal is prevention, not management.
    "PreDiabetes": [
        # food / prevention focus
        "Which foods can help prevent blood sugar from rising?",
        "What does a blood-sugar-friendly breakfast look like?",
        "What are simple food swaps to help my blood sugar?",
        "How do I build a balanced plate to keep blood sugar steady?",
        "What does a healthy day of eating look like for prediabetes?",
        "How does meal timing affect my blood sugar?",
        # condition-specific
        "Can I eat rice, bread, or pasta with prediabetes?",
        "What fruits are lower in sugar?",
        # grocery
        "What should go on my grocery list this week?",
        # snacks
        "What snacks won't spike my blood sugar?",
        # food label
        "How do I read a food label for sugar and carbs?",
        # hunger
        "What should I eat if I feel hungry between meals?",
        # dinner
        "What are easy dinner ideas that are lower in sugar?",
        # exercise
        "How can I stay active during the day?",
        "How does staying active help prevent blood sugar from rising?",
        # hydration
        "How much water should I drink daily?",
        # sleep
        "How does poor sleep affect blood sugar?",
        "How can I improve my sleep quality?",
    ],
}


# ---------------------------------------------------------------------------
# Starter question generator
# ---------------------------------------------------------------------------


def generate_starter_questions(
    conditions: list[str],
    user_profile: dict[str, Any] | None = None,
) -> list[str]:
    plan = _resolve_starter_plan(user_profile)
    pool = STARTER_QUESTION_POOLS[plan]

    lifestyle_keywords = {
        "sleep", "active", "water", "drink", "exercise", "hydrat"
    }
    food_qs = [q for q in pool if not any(k in q.lower() for k in lifestyle_keywords)]
    lifestyle_qs = [q for q in pool if any(k in q.lower() for k in lifestyle_keywords)]

    # Always show 2 food/plan questions first, then 3 lifestyle (shuffled).
    early_food = [
        q
        for q in food_qs
        if any(k in q.lower() for k in {"show", "example", "suggest", "plan"})
    ]
    specific_food = [q for q in food_qs if q not in early_food]
    chosen_food: list[str] = []
    if early_food:
        chosen_food.append(random.choice(early_food))
    if specific_food:
        chosen_food.append(random.choice(specific_food))
    if len(chosen_food) < 2:
        chosen_food = random.sample(food_qs, min(2, len(food_qs)))

    # Enforce sub-bucket uniqueness for lifestyle questions:
    # at most ONE exercise question, ONE sleep question, ONE hydration question.
    # This prevents two near-identical exercise questions appearing together
    # (e.g. "How can I stay active?" and "How does staying active help with diabetes?").
    _exercise_kw = {"active", "exercise"}
    _sleep_kw = {"sleep"}
    _hydration_kw = {"water", "drink", "hydrat"}
    lifestyle_by_topic: dict[str, list[str]] = {
        "exercise": [q for q in lifestyle_qs if any(k in q.lower() for k in _exercise_kw)],
        "sleep": [q for q in lifestyle_qs if any(k in q.lower() for k in _sleep_kw)],
        "hydration": [q for q in lifestyle_qs if any(k in q.lower() for k in _hydration_kw)],
    }
    chosen_lifestyle: list[str] = []
    for topic_pool in lifestyle_by_topic.values():
        if topic_pool:
            chosen_lifestyle.append(random.choice(topic_pool))
    # Shuffle so the order (exercise, sleep, hydration) varies across sessions.
    random.shuffle(chosen_lifestyle)
    chosen_lifestyle = chosen_lifestyle[:3]

    return chosen_food + chosen_lifestyle


# ---------------------------------------------------------------------------
# Follow-up question banks  (used by suggestion_engine.py)
# ---------------------------------------------------------------------------

QUESTION_BANK: dict[str, dict[str, list[str]]] = {
    "diabetes": {
        "food": [
            "What foods help keep my blood sugar steady?",
            "What meals are good for blood sugar control?",
            "Can you suggest simple meals that are easy on blood sugar?",
            "What should I eat for breakfast with diabetes?",
        ],
        "snacks": [
            "What snacks are good for managing my blood sugar?",
            "What can I eat when I feel hungry between meals?",
        ],
        "grocery": [
            "What should go on my grocery list this week?",
            "What are 5 foods I should always have at home?",
        ],
        "lifestyle": [
            "What does a healthy day of eating look like for diabetes?",
            "What habits help keep my blood sugar steady?",
        ],
    },
    "hypertension": {
        "food": [
            "What foods help lower my blood pressure?",
            "What meals are low in salt?",
            "Can you suggest simple DASH-style meals?",
            "Which fruits and vegetables are good for blood pressure?",
        ],
        "snacks": [
            "What are low-sodium snack options?",
            "What can I eat instead of salty snacks?",
        ],
        "grocery": [
            "What foods should I buy to reduce salt?",
            "What should I look for on food labels?",
        ],
        "lifestyle": [
            "How do I cook without adding too much salt?",
            "What is one food swap that helps my blood pressure?",
        ],
    },
    "obesity": {
        "food": [
            "What foods keep me full without too many calories?",
            "What meals keep me full longer?",
            "Can you suggest balanced, lower-calorie meals?",
            "What should I eat for a filling breakfast?",
        ],
        "snacks": [
            "What snacks help me stay full?",
            "What can I eat without overeating?",
        ],
        "grocery": [
            "What foods should I buy for weight loss?",
            "What are 5 foods I should always have at home?",
        ],
        "lifestyle": [
            "How can I manage my portions better?",
            "What is one eating habit I can start this week?",
        ],
    },
    "DiabetesPlate": {
        "food": [
            "Can you show a Diabetes Plate meal example?",
            "What foods fit well in the Diabetes Plate?",
            "How do I divide my plate for blood sugar control?",
            "What is a simple Diabetes Plate dinner?",
        ],
        "snacks": [
            "What snacks fit the Diabetes Plate approach?",
            "What can I eat without raising blood sugar quickly?",
        ],
    },
    "DASH": {
        "food": [
            "Can you show a DASH-style daily meal plan?",
            "What foods are low in sodium?",
            "What is a simple DASH dinner idea?",
            "What is a simple heart-healthy breakfast idea?",
        ],
        "snacks": [
            "What snacks are low in salt?",
            "What can I eat instead of chips?",
        ],
    },
    "MyPlate": {
        "food": [
            "Can you show a balanced MyPlate meal?",
            "How do I build a healthy plate?",
            "What is a simple meal I can try today?",
            "How do I balance grains, protein, and vegetables?",
        ],
        "snacks": [
            "What are healthy snack options?",
            "What can I eat between meals?",
        ],
        "grocery": [
            "What foods should I buy for balanced meals?",
            "What are 5 foods I should always have at home?",
        ],
    },
    "PreDiabetes": {
        "food": [
            "Which foods can help prevent blood sugar from rising?",
            "What does a blood-sugar-friendly meal look like?",
            "What are simple food swaps to help my blood sugar?",
            "What fruits are lower in sugar?",
        ],
        "snacks": [
            "What snacks won't spike my blood sugar?",
            "What can I eat between meals without raising blood sugar?",
            "What is a quick, blood-sugar-friendly snack?",
        ],
        "grocery": [
            "What should go on my grocery list for blood sugar health?",
            "What are 5 foods to always have at home for prediabetes?",
        ],
        "lifestyle": [
            "What does a healthy day of eating look like for prediabetes?",
            "What habits help keep blood sugar steady over time?",
        ],
    },
    "sleep": {
        "general": [
            "How many hours should I sleep each night?",
            "How can I improve my sleep quality?",
            "What habits help me sleep better?",
            "What foods help me sleep better at night?",
            "How does poor sleep affect my blood sugar or weight?",
        ]
    },
    "exercise": {
        "general": [
            "What exercises are safe for me?",
            "Can you suggest a simple workout plan?",
            "How can I stay active during the day?",
            "How much exercise do I need each week?",
            "What are easy ways to move more during the day?",
        ]
    },
    "hydration": {
        "general": [
            "How much water should I drink daily?",
            "How can I stay hydrated during the day?",
            "What drinks are better for my health?",
            "What drinks should I avoid for better health?",
            "How does staying hydrated help my blood sugar or blood pressure?",
        ]
    },
    "general": {
        "general": [
            "What should I do next for my health?",
            "Can you give me simple tips to follow?",
            "What is one small change I can start today?",
        ]
    },
}

COMBINATION_QUESTION_BANK: dict[tuple[str, ...], list[str]] = {
    # Triple condition — checked before any pair.
    ("diabetes", "hypertension", "obesity"): [
        "What meals help with blood sugar, blood pressure, and weight at the same time?",
        "What high-fiber, low-sodium foods also help with portion control?",
        "Can you suggest a meal that fits all three of my health goals?",
        "What snacks work well for blood sugar, blood pressure, and weight?",
        "What does a breakfast look like that helps all three of my conditions?",
        "What proteins work well for blood sugar, blood pressure, and weight?",
        "What vegetables are best for blood sugar, blood pressure, and weight together?",
        "How do I build a plate that balances blood sugar, sodium, and calories?",
        "What snacks are low in sugar, sodium, and calories all at once?",
        "Can you give me a simple lunch idea that fits all my health conditions?",
    ],
    # Prediabetes + hypertension — softer framing (prevention, not Diabetes Plate).
    # Checked before ("diabetes", "hypertension") via _generate_suggestions special-case.
    ("hypertension", "prediabetes"): [
        "What foods help keep my blood sugar steady and support healthy blood pressure?",
        "What are some blood-sugar-friendly, low-sodium meal ideas?",
        "What snacks are good for blood sugar and low in sodium?",
        "How do I eat to support both blood sugar and blood pressure health?",
        "What is a breakfast idea that is good for both blood sugar and blood pressure?",
        "What high-fiber, low-sodium foods help both of my conditions?",
        "What vegetables are good for both blood sugar and blood pressure?",
        "How do I cook to support blood sugar and heart health at the same time?",
        "What protein foods work well for prediabetes and high blood pressure?",
        "What snack is filling, low in sugar, and low in sodium?",
    ],
    # Pairs — checked in COMBINATION_PAIR_PRIORITY order.
    ("diabetes", "hypertension"): [
        "What foods help control blood sugar and reduce salt?",
        "Can you show a low-salt Diabetes Plate meal?",
        "What snacks are good for managing my blood sugar and low sodium?",
        "How can I reduce salt while keeping blood sugar steady?",
        "What high-fiber foods are also low in sodium?",
        "Can you suggest a low-sodium breakfast for blood sugar control?",
        "What protein sources are good for both blood sugar and blood pressure?",
        "How do I season food without salt when I have diabetes?",
        "What vegetables are best for blood sugar and heart health together?",
        "What is a simple lunch that fits both diabetes and high blood pressure?",
    ],
    ("diabetes", "obesity"): [
        "What meals help with blood sugar and weight management?",
        "What high-fiber foods keep me full while managing blood sugar?",
        "Can you suggest filling meals that are good for blood sugar and weight?",
        "What foods keep me full and help control blood sugar?",
        "What is a filling, low-carb breakfast for diabetes and weight loss?",
        "How can I control portion sizes for blood sugar and weight together?",
        "What are low-calorie, blood-sugar-friendly snacks?",
        "How do I add more fiber without adding too many calories?",
        "What proteins help with both blood sugar and feeling full?",
        "What does a diabetes-friendly, lower-calorie dinner look like?",
    ],
    ("hypertension", "obesity"): [
        "What foods are low in sodium and support a healthy weight?",
        "Can you suggest a heart-healthy meal plan?",
        "What snacks are low in salt and keep me full?",
        "How do I flavor low-sodium meals using herbs and spices?",
        "What is a heart-healthy, lower-calorie breakfast?",
        "What fruits and vegetables are good for blood pressure and weight?",
        "What high-fiber foods help with both weight and blood pressure?",
        "Can you suggest a simple low-sodium dinner that is also filling?",
        "What protein sources are good for blood pressure and weight management?",
        "How do I build a DASH-style plate that also helps with weight?",
    ],
}

# When a user has 3+ conditions, evaluate pairs in this priority order.
COMBINATION_PAIR_PRIORITY: tuple[tuple[str, str], ...] = (
    ("diabetes", "hypertension"),
    ("diabetes", "obesity"),
    ("hypertension", "obesity"),
)
