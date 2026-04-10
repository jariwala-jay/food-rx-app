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
from typing import Any

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.database import get_database
from app.deps import get_current_user_id
from app.services.conversation_state_service import get_state, reset_state, update_state
from app.services.rag_service import (
    is_session_closing,
    rag_service,
    should_suggest_follow_ups,
)

logger = logging.getLogger(__name__)
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
_INITIAL_GREETING = (
    "Hey! Let's talk about food, nutrition, and healthy eating. "
    "What do you need help with?"
)
_GENERIC_STARTER_QUESTIONS: list[str] = [
    "What foods are good for my condition?",
    "How can I improve my diet?",
    "What should I eat daily?",
    "How much water should I drink?",
    "What exercises are best for me?",
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


def _primary_condition(user_profile: dict[str, Any] | None) -> str | None:
    if not isinstance(user_profile, dict):
        return None
    conds = user_profile.get("medicalConditions") or []
    text = " ".join(str(c).lower() for c in conds)
    # Priority: diabetes > hypertension > obesity
    if any(k in text for k in ("diabetes", "prediabetes", "pre-diabetes", "blood sugar")):
        return "diabetes"
    if any(k in text for k in ("hypertension", "high blood pressure", "hbp")):
        return "hypertension"
    if any(k in text for k in ("obesity", "overweight", "weight")):
        return "obesity"
    return None


def _generate_suggestions(
    query: str,
    response: str,
    user_profile: dict[str, Any] | None,
) -> list[str]:
    """
    Return optional, lightweight follow-up suggestions for free-chat replies.
    Suggestions are non-blocking prompts (not guided-flow state).
    """
    if not should_suggest_follow_ups(response):
        return []

    q = query.lower()
    condition = _primary_condition(user_profile)

    # Condition-gated suggestions first: avoid unrelated plans.
    if condition == "diabetes":
        if any(w in q for w in ("diet", "food", "meal", "eat", "plate", "carb", "sugar", "glucose")):
            return [
                "Diabetes-friendly meal plan",
                "Foods to help control blood sugar",
            ]
        return [
            "Diabetes Plate day plan",
            "Low glycemic food options",
        ]
    if condition == "hypertension":
        if any(w in q for w in ("diet", "food", "meal", "salt", "sodium", "pressure", "dash")):
            return [
                "Low-sodium meal ideas",
                "Simple DASH-style day plan",
            ]
        return [
            "DASH grocery list basics",
            "Low-sodium snack ideas",
        ]
    if condition == "obesity":
        if any(w in q for w in ("diet", "food", "meal", "weight", "calorie", "portion")):
            return [
                "MyPlate meal plan",
                "Balanced calorie meal ideas",
            ]
        return [
            "Portion-control tips",
            "Simple weight-loss meal pattern",
        ]

    if "egg" in q or "eggs" in q:
        return [
            "More about eggs",
            "Recipes using eggs",
        ]
    if "diabet" in q or "blood sugar" in q or "glucose" in q:
        return [
            "Diabetes-friendly diet plan",
            "Foods to avoid for blood sugar",
        ]
    if "sleep" in q or "insomnia" in q:
        return [
            "Bedtime food tips",
            "Simple sleep routine",
        ]
    if "water" in q or "hydrat" in q:
        return [
            "Daily water target",
            "Hydration tips for hot days",
        ]
    if "exercise" in q or "workout" in q or "walking" in q:
        return [
            "Beginner weekly exercise plan",
            "Pre- and post-workout meal ideas",
        ]
    if "pressure" in q or "hypertension" in q or "sodium" in q or "dash" in q:
        return [
            "Low-sodium meal ideas",
            "Simple DASH-style day plan",
        ]
    if "weight" in q or "obesity" in q:
        return [
            "Portion-control tips",
            "Simple weight-loss meal pattern",
        ]
    if any(w in q for w in ("food", "diet", "meal", "nutrition", "healthy")):
        return [
            "One-day sample meal plan",
            "Easy snack ideas",
        ]
    return []


async def _fetch_user_profile_and_pantry(
    db: Any, user_id: str
) -> tuple[dict[str, Any] | None, list[dict]]:
    """
    Load user profile and pantry from MongoDB.
    Failures degrade gracefully: RAG still runs without personalisation.
    """
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
    user_id: str = Depends(get_current_user_id),
) -> StarterQuestionsResponse:
    """
    Returns generic starter questions as chips when chat opens.
    Keep these condition-agnostic to avoid incorrect plan assumptions in initial UX.
    """
    _ = user_id  # Reserved for future personalization without changing API contract.
    return StarterQuestionsResponse(questions=list(_GENERIC_STARTER_QUESTIONS))


@router.post("/chat", response_model=ChatResponse)
async def chat(
    body: ChatRequest,
    user_id: str = Depends(get_current_user_id),
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
        return ChatResponse(
            response=_INITIAL_GREETING,
            follow_up_questions=list(_GENERIC_STARTER_QUESTIONS),
            session_closing=False,
        )

    state = await get_state(user_id, conversation_id)

    # Closing messages end guided flow immediately.
    if is_session_closing(message):
        await reset_state(user_id, conversation_id)
        db = await get_database()
        user_profile, pantry_items = await _fetch_user_profile_and_pantry(db, user_id)
        response_text = await rag_service.chat(
            message=normalized_message,
            history=history,
            user_profile=user_profile,
            pantry_items=pantry_items,
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
        return ChatResponse(
            response=f"{topic} selected. Answer these to personalize your guidance.",
            follow_up_questions=list(_TOPIC_FOLLOWUPS[topic]),
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
                return ChatResponse(
                    response="Thanks. Please answer the next question.",
                    follow_up_questions=[questions[step]],
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
            )
            follow_ups = _generate_suggestions(
                query=f"{selected_topic} {message}",
                response=response_text,
                user_profile=user_profile,
            )
            return ChatResponse(
                response=response_text,
                follow_up_questions=follow_ups,
                session_closing=False,
            )
        await reset_state(user_id, conversation_id)

    db = await get_database()
    user_profile, pantry_items = await _fetch_user_profile_and_pantry(db, user_id)
    try:
        response_text = await rag_service.chat(
            message=normalized_message,
            history=history,
            user_profile=user_profile,
            pantry_items=pantry_items,
        )
    except Exception as exc:
        logger.error("RAG pipeline error for user %s: %s", user_id, exc, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="The assistant encountered an error. Please try again.",
        ) from exc

    follow_ups = _generate_suggestions(
        query=message,
        response=response_text,
        user_profile=user_profile,
    )

    return ChatResponse(
        response=response_text,
        follow_up_questions=follow_ups,
        session_closing=False,
    )
