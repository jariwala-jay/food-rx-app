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
from app.routers.question_banks import (
    _extract_profile_conditions,
    generate_starter_questions,
)
from app.routers.suggestion_engine import (
    clear_suggestion_memory,
    clear_suggestion_memory_db,
    generate_followup_chips,
)
from app.services.conversation_history_service import (
    clear_history,
    load_history,
    save_message,
)
from app.services.conversation_state_service import get_state, reset_state, update_state
from app.services.rag_service import (
    is_polite_chat_turn,
    is_session_closing,
    rag_service,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chatbot", tags=["chatbot"])


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------


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
    session_closing: bool = False


class StarterQuestionsResponse(BaseModel):
    questions: list[str]


# ---------------------------------------------------------------------------
# Legacy topic-guided flow (Dialogflow-era; kept for backwards compat)
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Profile / greeting helpers
# ---------------------------------------------------------------------------


def _profile_condition_flags(
    user_profile: dict[str, Any] | None,
) -> dict[str, bool]:
    """Which condition themes appear in medicalConditions."""
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
    if re.search(r"prediabetes|pre-diabetes|prediabetic|borderline\s+diabetes", text):
        out["prediabetes"] = True
    if re.search(r"\bdiabetes\b|blood\s*sugar", text):
        out["diabetes"] = True
    if any(k in text for k in ("hypertension", "high blood pressure", "hbp")):
        out["hypertension"] = True
    if any(k in text for k in ("obesity", "overweight", "weight")):
        out["obesity"] = True
    return out


def _user_first_name(user_profile: dict[str, Any] | None) -> str | None:
    if not isinstance(user_profile, dict):
        return None
    raw = user_profile.get("name")
    if not raw or not str(raw).strip():
        return None
    first = str(raw).strip().split()[0]
    first = re.sub(r"^[^\w]+|[^\w]+$", "", first, flags=re.UNICODE)
    if not first or len(first) > 48:
        return None
    return first


def _greeting_for_profile(user_profile: dict[str, Any] | None) -> str:
    fn = _user_first_name(user_profile)
    f = _profile_condition_flags(user_profile)
    diabetes = f["diabetes"]
    prediabetes = f["prediabetes"]
    hypertension = f["hypertension"]
    obesity = f["obesity"]

    def _hey(message: str) -> str:
        return f"Hey {fn}! {message}" if fn else f"Hey! {message}"

    if diabetes and hypertension and obesity:
        return _hey(
            "I'm here to help you choose foods and build healthy habits that support your blood sugar, blood pressure and overall health. What would you like to start with?"
        )
    if diabetes and obesity:
        return _hey(
            "I'm here to help you with balanced nutrition and food choices that keep your blood sugar steady while supporting healthy habits and overall well-being. What would you like to start with?"
        )
    if prediabetes and obesity:
        return _hey(
            "I'm here to help you make small, sustainable food and nutrition changes that support your blood sugar and overall health while building healthy habits. Want to explore some easy wins?"
        )
    if hypertension and obesity:
        return _hey(
            "I'm here to help you build heart-healthy eating habits and make nutrition choices that support your blood pressure and overall health. What sounds good to you today?"
        )
    if hypertension and diabetes:
        return _hey(
            "I'm here to help you choose balanced foods and build healthy eating habits that support both your blood pressure and blood sugar. What would you like to start with?"
        )
    if diabetes:
        return _hey(
            "I'm here to support you with nutrition and food choices that help keep your blood sugar steady and support your overall health. What would you like help with today?"
        )
    if prediabetes:
        return _hey(
            "I'm here to help you make simple food and nutrition changes that can keep your blood sugar steady and support your long-term health. What would you like to work on?"
        )
    if hypertension:
        return _hey(
            "I'm here to help you build heart-healthy eating habits and make nutrition choices that support your blood pressure. Where would you like to begin?"
        )
    if obesity:
        return _hey(
            "I'm here to help you build healthy eating habits and simple nutrition routines that fit your lifestyle and support your overall health. What would you like to focus on?"
        )
    return _hey(
        "I'm here to help you eat well, build healthy habits, and feel your best. What would you like to start with today?"
    )


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _apply_follow_up_prelude(response: str, follow_ups: list[str]) -> str:
    """Strip follow-up prelude text; chips are sent as a separate field."""
    _ = follow_ups
    return (response or "").strip()


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
    """Strip suggestion-question preamble before RAG lookup."""
    text = message.strip()
    low = text.lower()
    for prefix in (
        "do you want ",
        "would you like ",
        "do you want to ",
        "would you like to ",
    ):
        if low.startswith(prefix):
            text = text[len(prefix) :].strip()
            break
    if text.endswith("?"):
        text = text[:-1].strip()
    return text or message.strip()


async def _fetch_user_profile_and_pantry(
    db: Any, user_id: str
) -> tuple[dict[str, Any] | None, list[dict]]:
    """Load user profile and pantry from MongoDB; failures degrade gracefully."""
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


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("/starter-questions", response_model=StarterQuestionsResponse)
async def get_starter_questions(
    user_id: str = Depends(get_chatbot_user_id),
) -> StarterQuestionsResponse:
    """Return 5 personalised starter questions for the current user."""
    db = await get_database()
    user_profile, _ = await _fetch_user_profile_and_pantry(db, user_id)
    conditions = _extract_profile_conditions(user_profile)
    return StarterQuestionsResponse(
        questions=generate_starter_questions(conditions, user_profile)
    )


@router.post("/chat", response_model=ChatResponse)
async def chat(
    body: ChatRequest,
    user_id: str = Depends(get_chatbot_user_id),
) -> ChatResponse:
    """
    Run the RAG chat pipeline and attach follow-up chips.

    Handles:
      - Initial handshake ("" or "start") → greeting + starter chips
      - Session-closing signals → goodbye, no chips
      - Legacy topic-guided flow (Sleep / Hydration / Exercise / Diet / Condition)
      - Normal RAG turns → answer + 2 follow-up chips
    """
    message = (body.message or "").strip()
    normalized_message = _normalize_user_query_for_rag(message)
    conversation_id = (
        body.conversation_id or body.session_id or "default"
    ).strip() or "default"
    # client_history used only as fallback for anon users who cannot be persisted
    client_history = [{"role": t.role, "parts": t.parts} for t in body.history]

    # ── Initial handshake ──────────────────────────────────────────────────
    if not message or message.lower() == "start":
        await reset_state(user_id, conversation_id)
        db = await get_database()
        await clear_suggestion_memory_db(db, user_id, conversation_id)
        await clear_history(db, user_id, conversation_id)
        user_profile, _ = await _fetch_user_profile_and_pantry(db, user_id)
        greeting = _greeting_for_profile(user_profile)
        starters = generate_starter_questions(
            _extract_profile_conditions(user_profile), user_profile
        )
        return ChatResponse(
            response=_apply_follow_up_prelude(greeting, starters),
            follow_up_questions=starters,
            session_closing=False,
        )

    state = await get_state(user_id, conversation_id)

    # ── Session-closing signals ────────────────────────────────────────────
    if is_session_closing(message):
        await reset_state(user_id, conversation_id)
        db = await get_database()
        await clear_suggestion_memory_db(db, user_id, conversation_id)
        history = await load_history(db, user_id, conversation_id) or client_history
        user_profile, pantry_items = await _fetch_user_profile_and_pantry(db, user_id)
        response_text = await rag_service.chat(
            message=normalized_message,
            history=history,
            user_profile=user_profile,
            pantry_items=pantry_items,
            user_id=user_id,
        )
        await save_message(db, user_id, conversation_id, "user", normalized_message)
        await save_message(db, user_id, conversation_id, "model", response_text)
        await clear_history(db, user_id, conversation_id)
        return ChatResponse(
            response=response_text,
            follow_up_questions=[],
            session_closing=True,
        )

    # ── Legacy topic-guided flow ───────────────────────────────────────────
    topic = _selected_topic(message)
    if topic:
        await update_state(
            user_id,
            conversation_id,
            {"stage": "followup", "selected_topic": topic, "step": 0, "answers": {}},
        )
        topic_chips = list(_TOPIC_FOLLOWUPS[topic])
        return ChatResponse(
            response=_apply_follow_up_prelude(
                f"{topic} selected. Answer these to personalize your guidance.",
                topic_chips,
            ),
            follow_up_questions=topic_chips,
            session_closing=False,
        )

    if state.get("stage") == "followup":
        selected_topic = str(state.get("selected_topic") or "")
        if selected_topic in _TOPIC_FOLLOWUPS:
            questions = _TOPIC_FOLLOWUPS[selected_topic]
            answers = (
                state.get("answers") if isinstance(state.get("answers"), dict) else {}
            )
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
                return ChatResponse(
                    response=_apply_follow_up_prelude(
                        "Thanks. Please answer the next question.", next_q
                    ),
                    follow_up_questions=next_q,
                    session_closing=False,
                )
            summary = _build_followup_summary(selected_topic, answers)
        await reset_state(user_id, conversation_id)
        db = await get_database()
        history = await load_history(db, user_id, conversation_id) or client_history
        user_profile, pantry_items = await _fetch_user_profile_and_pantry(
            db, user_id
        )
        response_text = await rag_service.chat(
            message=summary,
            history=history,
            user_profile=user_profile,
            pantry_items=pantry_items,
            user_id=user_id,
        )
        await save_message(db, user_id, conversation_id, "user", message)
        await save_message(db, user_id, conversation_id, "model", response_text)
        follow_ups = await generate_followup_chips(
            db=db,
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

    # ── Normal RAG turn ────────────────────────────────────────────────────
    db = await get_database()
    history = await load_history(db, user_id, conversation_id) or client_history
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
    await save_message(db, user_id, conversation_id, "user", normalized_message)
    await save_message(db, user_id, conversation_id, "model", response_text)

    if is_polite_chat_turn(message):
        follow_ups = []
    else:
        follow_ups = await generate_followup_chips(
            db=db,
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
