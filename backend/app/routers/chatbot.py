"""
Chatbot router — POST /chatbot/chat, GET /chatbot/starter-questions

RAG-powered chatbot: loads user profile and pantry from MongoDB, then runs the RAG service.

Response contract for Flutter:
  GET /chatbot/starter-questions → { "questions": [str × 5] }
  POST /chatbot/chat              → { "response": str,
                                       "follow_up_questions": [str × 0–n],
                                       "session_closing": bool }

Flutter may use session_closing=true to hide the suggested-question chip row on the same
response (thanks / ok / bye / …) without inferring from an empty follow_up_questions list.
"""

from __future__ import annotations

import logging
import re
from typing import Any

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.database import get_database
from app.deps import get_chatbot_user_id
from app.services.conversation_state_service import get_state, reset_state, update_state
from app.services.rag_service import (
    _infer_kb_categories,
    is_polite_chat_turn,
    is_session_closing,
    rag_service,
    should_suggest_follow_ups,
)

logger = logging.getLogger(__name__)

_last_suggestion_pair: dict[tuple[str, str], tuple[str, str]] = {}
_last_suggestion_context: dict[tuple[str, str], dict[str, Any]] = {}


def _clear_suggestion_memory(user_id: str, conversation_id: str) -> None:
    k = (user_id, conversation_id)
    _last_suggestion_pair.pop(k, None)
    _last_suggestion_context.pop(k, None)


def _apply_follow_up_prelude(response: str, follow_ups: list[str]) -> str:
    """Return assistant body; follow-up chips are separate fields (no extra transition text)."""
    _ = follow_ups
    return (response or "").strip()


def _profile_condition_flags(
    user_profile: dict[str, Any] | None,
) -> dict[str, bool]:
    """Which condition themes appear in medicalConditions (user may have several)."""
    out = {
        "prediabetes": False,
        "diabetes": False,
        "hypertension": False,
        "obesity": False,
    }
    if not isinstance(user_profile, dict):
        return out
    conds = user_profile.get("medicalConditions") or []
    text = " ".join(str(c).lower() for c in conds)
    if re.search(
        r"prediabetes|pre-diabetes|prediabetic|borderline\s+diabetes",
        text,
    ):
        out["prediabetes"] = True
    if re.search(r"\bdiabetes\b|blood\s*sugar", text):
        out["diabetes"] = True
    if any(k in text for k in ("hypertension", "high blood pressure", "hbp")):
        out["hypertension"] = True
    if any(k in text for k in ("obesity", "overweight", "weight")):
        out["obesity"] = True
    return out


def _user_first_name(user_profile: dict[str, Any] | None) -> str | None:
    """First name for greetings/sign-offs only (not injected into every RAG reply)."""
    if not isinstance(user_profile, dict):
        return None
    raw = user_profile.get("name")
    if not raw or not str(raw).strip():
        return None
    first = str(raw).strip().split()[0]
    # Strip common trailing punctuation from stored names
    first = re.sub(r"^[^\w]+|[^\w]+$", "", first, flags=re.UNICODE)
    if not first or len(first) > 48:
        return None
    return first


def _greeting_for_profile(user_profile: dict[str, Any] | None) -> str:
    fn = _user_first_name(user_profile)

    if fn:
        base = f"Hi {fn}! 😊 I'm here to help you eat well, feel great, and make healthy choices easier."
    else:
        base = "Hi! 😊 I'm here to help you eat well, feel great, and make healthy choices easier."

    f = _profile_condition_flags(user_profile)

    # Multi-condition
    if f["diabetes"] and f["obesity"]:
        return base + "\nLet's focus on meals that keep your blood sugar steady and help you stay full and energized. What would you like to start with?"

    if f["prediabetes"] and f["obesity"]:
        return base + "\nSmall food changes can make a big difference for your blood sugar and weight. Want to explore some easy wins?"

    if f["hypertension"] and f["obesity"]:
        return base + "\nWe can build heart-friendly meals that are both tasty and satisfying. What sounds good to you today?"

    # Single condition
    if f["diabetes"]:
        return base + "\nLet's make managing blood sugar simpler with the right food choices. What would you like help with?"

    if f["prediabetes"]:
        return base + "\nYou can turn things around with a few smart food swaps. Want to see how?"

    if f["hypertension"]:
        return base + "\nLet's create heart-healthy meals without sacrificing flavor. Where would you like to begin?"

    if f["obesity"]:
        return base + "\nWe can build simple, sustainable habits that actually stick. What would you like to focus on?"

    # Default
    return base + "\nWhat would you like to start with today?"


router = APIRouter(prefix="/chatbot", tags=["chatbot"])

_TOPIC_FOLLOWUPS: dict[str, list[str]] = {
    "Sleep": [
        "How many hours do you sleep?",
        "Do you feel rested in the morning?",
    ],
    "Hydration": [
        "How much water do you drink daily?",
        "Do you feel thirsty often?",
    ],
    "Exercise": [
        "How often do you exercise?",
        "What type of activity do you do?",
    ],
    "Diet": [
        "How many meals do you eat daily?",
        "Do you include fruits and vegetables?",
    ],
    "Condition": [
        "Are you managing any condition like diabetes or hypertension?",
        "Would you like general lifestyle tips?",
    ],
}
_TOPIC_BY_LOWER = {k.lower(): k for k in _TOPIC_FOLLOWUPS}
GENERIC_STARTER_QUESTIONS: list[str] = [
    "What foods are best for managing my {condition}?",
    "What diet changes should I follow for {condition}?",
    "What exercises are safe and helpful for {condition}?",
    "How much water should I drink daily?",
    "How can I improve my sleep?",
]


class HistoryTurn(BaseModel):
    role: str
    parts: list[str]


class ChatRequest(BaseModel):
    message: str
    history: list[HistoryTurn] = Field(default_factory=list)
    conversation_id: str | None = None
    session_id: str | None = None


class ChatResponse(BaseModel):
    response: str
    follow_up_questions: list[str] = Field(default_factory=list)
    # True when the user message matched closing / small-talk signals (see rag_service.is_session_closing).
    session_closing: bool = False


class StarterQuestionsResponse(BaseModel):
    questions: list[str]


def _normalize_condition_text(value: Any) -> str:
    text = " ".join(str(value or "").strip().split())
    return text


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
    """Human-readable condition phrase for starter questions."""
    clean = [_normalize_condition_text(c) for c in conditions if _normalize_condition_text(c)]
    if not clean:
        return "my condition"
    if len(clean) == 1:
        return clean[0]
    if len(clean) == 2:
        return f"{clean[0]} and {clean[1]}"
    return ", ".join(clean[:-1]) + f", and {clean[-1]}"


def generate_starter_questions(conditions: list[str]) -> list[str]:
    """
    Keep starter list fixed at 5 and only replace ``{condition}`` placeholders.
    """
    condition_text = format_conditions(conditions)
    questions: list[str] = []
    for template in GENERIC_STARTER_QUESTIONS:
        q = template.replace("{condition}", condition_text) if "{condition}" in template else template
        q = " ".join(q.split())
        questions.append(q)
    return questions[:5]


def _selected_topic(message: str) -> str | None:
    return _TOPIC_BY_LOWER.get(message.strip().lower())


def _build_followup_summary(topic: str, answers: dict[str, Any]) -> str:
    lines = [f"User selected topic: {topic}.", "Follow-up answers:"]
    for key in sorted(answers.keys()):
        lines.append(f"- {key}: {answers[key]}")
    lines.append(
        "Provide short, practical lifestyle and food guidance aligned with the user's profile."
    )
    return "\n".join(lines)


def _normalize_user_query_for_rag(message: str) -> str:
    """
    Convert suggestion-like prompts into direct intent before RAG.
    Example:
    - "Do you want a simple DASH-style day plan?" -> "simple DASH-style day plan"
    """
    text = message.strip()
    low = text.lower()
    prefixes = (
        "do you want ",
        "would you like ",
        "do you want to ",
        "would you like to ",
    )
    for prefix in prefixes:
        if low.startswith(prefix):
            text = text[len(prefix):].strip()
            break
    if text.endswith("?"):
        text = text[:-1].strip()
    return text or message.strip()


QUESTION_BANK: dict[str, dict[str, list[str]]] = {
    "diabetes": {
        "food": [
            "What foods help control my blood sugar?",
            "Can you suggest a simple diabetes meal plan?",
        ],
        "lifestyle": [
            "How can I manage my blood sugar daily?",
            "What habits improve blood sugar control?",
        ],
    },
    "hypertension": {
        "food": [
            "What foods help lower my blood pressure?",
            "Can you suggest a DASH-style meal plan?",
        ],
        "lifestyle": [
            "How can I reduce salt in my meals?",
            "What habits help control blood pressure?",
        ],
    },
    "obesity": {
        "food": [
            "What foods help with healthy weight loss?",
            "Can you suggest a balanced meal plan for me?",
        ],
        "lifestyle": [
            "How can I manage my portions better?",
            "What habits help with weight loss?",
        ],
    },
    "DiabetesPlate": {
        "food": [
            "Can you show a Diabetes Plate meal example?",
            "What foods fit well in the Diabetes Plate?",
        ]
    },
    "DASH": {
        "food": [
            "Can you show a DASH-style daily meal plan?",
            "What foods are low in sodium?",
        ]
    },
    "MyPlate": {
        "food": [
            "Can you show a balanced MyPlate meal?",
            "How do I build a healthy plate?",
        ]
    },
    "Sleep": {
        "general": [
            "How many hours should I sleep?",
            "How can I improve my sleep quality?",
        ]
    },
    "Exercise": {
        "general": [
            "What exercises are safe for me?",
            "Can you suggest a simple workout plan?",
        ]
    },
    "Hydration": {
        "general": [
            "How much water should I drink daily?",
            "How can I stay hydrated during the day?",
        ]
    },
    "general": {
        "general": [
            "What should I do next for my health?",
            "Can you give me simple tips to follow?",
        ]
    },
}

COMBINATION_QUESTION_BANK: dict[tuple[str, str], list[str]] = {
    (
        "diabetes",
        "hypertension",
    ): [
        "What foods fit the Diabetes Plate and are low in salt?",
        "Can you show a low-salt Diabetes Plate meal plan?",
    ],
    ("diabetes", "obesity"): [
        "What meals help with blood sugar and weight loss?",
        "Can you suggest filling, low-carb meals?",
    ],
    ("hypertension", "obesity"): [
        "What foods are low in salt and help with weight loss?",
        "Can you suggest a heart-healthy meal plan?",
    ],
}


def _rag_category_label(query: str) -> str | None:
    """
    Single label for template refinement, aligned with RAG retrieval categories.
    """
    cats = _infer_kb_categories(query)
    if not cats:
        return None
    if "exercise" in cats:
        return "Exercise"
    if "sleep" in cats:
        return "Sleep"
    if "hydration" in cats:
        return "Hydration"
    if "diabetes" in cats or "pre-diabetes" in cats:
        return "Diabetes"
    if "hypertension" in cats:
        return "Hypertension"
    if "obesity" in cats:
        return "Obesity"
    return None


def _all_conditions(user_profile: dict[str, Any] | None) -> list[str]:
    if not isinstance(user_profile, dict):
        return []

    raw = user_profile.get("conditions") or user_profile.get("medicalConditions") or []
    if isinstance(raw, str):
        raw = [raw]

    out: set[str] = set()
    for condition in raw:
        text = str(condition).lower()
        if "prediabetes" in text:
            out.add("diabetes")
        elif "diabetes" in text:
            out.add("diabetes")
        elif "hypertension" in text or "blood pressure" in text:
            out.add("hypertension")
        elif "obesity" in text or "overweight" in text:
            out.add("obesity")

    return sorted(out)


def _primary_condition_multi(conditions: list[str]) -> str | None:
    if "diabetes" in conditions:
        return "diabetes"
    if "hypertension" in conditions:
        return "hypertension"
    if "obesity" in conditions:
        return "obesity"
    return None


def _normalized_plan_key(user_profile: dict[str, Any] | None) -> str | None:
    if not isinstance(user_profile, dict):
        return None

    raw_plan = user_profile.get("dietType") or user_profile.get("myPlanType")
    if not raw_plan:
        return None

    plan_text = str(raw_plan).strip().lower().replace("-", " ")
    compact = plan_text.replace(" ", "")

    if compact in {"diabetesplate", "diabetes"} or "diabetes plate" in plan_text:
        return "DiabetesPlate"
    if compact in {"dash", "dashdiet"} or "dash" in plan_text:
        return "DASH"
    if compact in {"myplate", "plate"} or "myplate" in plan_text or "my plate" in plan_text:
        return "MyPlate"
    return str(raw_plan).strip()


def _generate_suggestions(
    query: str,
    response: str,
    user_profile: dict[str, Any] | None,
    user_id: str,
    conversation_id: str,
) -> list[str]:
    """
    Clean, deterministic follow-up generator based on:
    1. Multi-condition combination
    2. Assigned plan (source of truth)
    3. Condition
    4. RAG category
    5. Fallback

    Always returns 2 relevant, natural follow-up questions.
    """

    if not should_suggest_follow_ups(response):
        return []

    _ = (user_id, conversation_id)

    conditions = _all_conditions(user_profile)
    primary = _primary_condition_multi(conditions)
    category = _rag_category_label(query)

    plan = _normalized_plan_key(user_profile)

    response_lower = (response or "").lower()

    # Combination-first path for multi-condition users.
    if len(conditions) >= 2:
        for combo_key, questions in COMBINATION_QUESTION_BANK.items():
            if all(c in conditions for c in combo_key):
                return questions[:2]

    # Lightweight response awareness for wellness categories.
    question_type = "food"
    if not primary:
        if any(k in response_lower for k in ["exercise", "walk", "activity"]):
            question_type = "general"
            category = "Exercise"
        elif "sleep" in response_lower:
            question_type = "general"
            category = "Sleep"
        elif any(k in response_lower for k in ["water", "hydration"]):
            question_type = "general"
            category = "Hydration"

    # Plan-based (source of truth).
    if plan and plan in QUESTION_BANK:
        bucket = QUESTION_BANK[plan]
        return list(bucket.values())[0][:2]

    # Condition-based fallback.
    if primary and primary in QUESTION_BANK:
        bucket = QUESTION_BANK[primary]
        if question_type in bucket:
            return bucket[question_type][:2]
        return list(bucket.values())[0][:2]

    # Category-based.
    if category and category in QUESTION_BANK:
        bucket = QUESTION_BANK[category]
        return list(bucket.values())[0][:2]

    # Fallback.
    return QUESTION_BANK["general"]["general"][:2]


async def _fetch_user_profile_and_pantry(
    db: Any, user_id: str
) -> tuple[dict[str, Any] | None, list[dict]]:
    """
    Load user profile and pantry from MongoDB.
    Failures degrade gracefully: RAG still runs without personalisation.
    """
    if user_id == "anon":
        return None, []

    user_profile: dict[str, Any] | None = None
    try:
        user_profile = await db["users"].find_one({"_id": ObjectId(user_id)})
    except Exception as exc:
        logger.warning("Could not fetch user profile for %s: %s", user_id, exc)

    pantry_items: list[dict] = []
    try:
        cursor = db["pantry_items"].find({"userId": ObjectId(user_id)}).limit(30)
        pantry_items = await cursor.to_list(length=30)
    except Exception as exc:
        logger.warning("Could not fetch pantry items for %s: %s", user_id, exc)

    return user_profile, pantry_items


@router.get("/starter-questions", response_model=StarterQuestionsResponse)
async def get_starter_questions(
    user_id: str = Depends(get_chatbot_user_id),
) -> StarterQuestionsResponse:
    """
    Return personalized starter questions for the current user.
    """
    db = await get_database()
    user_profile, _ = await _fetch_user_profile_and_pantry(db, user_id)
    conditions = _extract_profile_conditions(user_profile)
    return StarterQuestionsResponse(questions=generate_starter_questions(conditions))


@router.post("/chat", response_model=ChatResponse)
async def chat(
    body: ChatRequest,
    user_id: str = Depends(get_chatbot_user_id),
) -> ChatResponse:
    """
    Run the RAG chat pipeline and optionally attach follow-up chips.

    If the user message is a session-closing signal (thanks, ok, bye, …), returns
    session_closing=true and empty follow_up_questions without calling the follow-up model.
    Otherwise, when the assistant reply is substantive, generates follow-up questions.
    """
    message = (body.message or "").strip()
    normalized_message = _normalize_user_query_for_rag(message)
    conversation_id = (
        body.conversation_id or body.session_id or "default"
    ).strip() or "default"
    history = [{"role": t.role, "parts": t.parts} for t in body.history]

    # Initial open handshake: allow empty or explicit "start".
    if not message or message.lower() == "start":
        await reset_state(user_id, conversation_id)
        _clear_suggestion_memory(user_id, conversation_id)
        db = await get_database()
        user_profile, _ = await _fetch_user_profile_and_pantry(db, user_id)
        greeting = _greeting_for_profile(user_profile)
        starters = generate_starter_questions(_extract_profile_conditions(user_profile))
        return ChatResponse(
            response=_apply_follow_up_prelude(greeting, starters),
            follow_up_questions=starters,
            session_closing=False,
        )

    state = await get_state(user_id, conversation_id)

    # Closing messages end guided flow immediately.
    if is_session_closing(message):
        await reset_state(user_id, conversation_id)
        _clear_suggestion_memory(user_id, conversation_id)
        db = await get_database()
        user_profile, pantry_items = await _fetch_user_profile_and_pantry(db, user_id)
        response_text = await rag_service.chat(
            message=normalized_message,
            history=history,
            user_profile=user_profile,
            pantry_items=pantry_items,
            user_id=user_id,
        )
        fn = _user_first_name(user_profile)
        if fn:
            response_text = (
                response_text.rstrip()
                + f"\n\nThanks for chatting, {fn}. Take care, and come back anytime "
                "if you have more food or nutrition questions."
            )
        return ChatResponse(
            response=response_text,
            follow_up_questions=[],
            session_closing=True,
        )

    topic = _selected_topic(message)
    if topic:
        # Topic switch (including mid-flow): start a fresh guided flow.
        await update_state(
            user_id,
            conversation_id,
            {
                "stage": "followup",
                "selected_topic": topic,
                "step": 0,
                "answers": {},
            },
        )
        topic_intro = f"{topic} selected. Answer these to personalize your guidance."
        topic_chips = list(_TOPIC_FOLLOWUPS[topic])
        return ChatResponse(
            response=_apply_follow_up_prelude(topic_intro, topic_chips),
            follow_up_questions=topic_chips,
            session_closing=False,
        )

    if state.get("stage") == "followup":
        selected_topic = str(state.get("selected_topic") or "")
        if selected_topic in _TOPIC_FOLLOWUPS:
            questions = _TOPIC_FOLLOWUPS[selected_topic]
            answers = state.get("answers") if isinstance(state.get("answers"), dict) else {}
            step = int(state.get("step") or 0)
            if step < len(questions):
                answers[f"q{step + 1}"] = message
                step += 1
                await update_state(
                    user_id,
                    conversation_id,
                    {
                        "stage": "followup",
                        "selected_topic": selected_topic,
                        "step": step,
                        "answers": answers,
                    },
                )
            if step < len(questions):
                next_q = [questions[step]]
                thanks = "Thanks. Please answer the next question."
                return ChatResponse(
                    response=_apply_follow_up_prelude(thanks, next_q),
                    follow_up_questions=next_q,
                    session_closing=False,
                )
            summary = _build_followup_summary(selected_topic, answers)
            await reset_state(user_id, conversation_id)
            db = await get_database()
            user_profile, pantry_items = await _fetch_user_profile_and_pantry(db, user_id)
            response_text = await rag_service.chat(
                message=summary,
                history=history,
                user_profile=user_profile,
                pantry_items=pantry_items,
                user_id=user_id,
            )
            follow_ups = _generate_suggestions(
                query=f"{selected_topic} {message}",
                response=response_text,
                user_profile=user_profile,
                user_id=user_id,
                conversation_id=conversation_id,
            )
            return ChatResponse(
                response=_apply_follow_up_prelude(response_text, follow_ups),
                follow_up_questions=follow_ups,
                session_closing=False,
            )
        await reset_state(user_id, conversation_id)
        _clear_suggestion_memory(user_id, conversation_id)

    db = await get_database()
    user_profile, pantry_items = await _fetch_user_profile_and_pantry(db, user_id)
    try:
        response_text = await rag_service.chat(
            message=normalized_message,
            history=history,
            user_profile=user_profile,
            pantry_items=pantry_items,
            user_id=user_id,
        )
    except Exception as exc:
        logger.error("RAG pipeline error for user %s: %s", user_id, exc, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="The assistant encountered an error. Please try again.",
        ) from exc

    if is_polite_chat_turn(message):
        follow_ups = generate_starter_questions(_extract_profile_conditions(user_profile))
    else:
        follow_ups = _generate_suggestions(
            query=message,
            response=response_text,
            user_profile=user_profile,
            user_id=user_id,
            conversation_id=conversation_id,
        )

    return ChatResponse(
        response=_apply_follow_up_prelude(response_text, follow_ups),
        follow_up_questions=follow_ups,
        session_closing=False,
    )
