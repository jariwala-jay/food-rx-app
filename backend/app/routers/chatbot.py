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
from app.services.rag_service import (
    is_session_closing,
    rag_service,
    should_suggest_follow_ups,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/chatbot", tags=["chatbot"])


class HistoryTurn(BaseModel):
    role: str
    parts: list[str]


class ChatRequest(BaseModel):
    message: str
    history: list[HistoryTurn] = Field(default_factory=list)


class ChatResponse(BaseModel):
    response: str
    follow_up_questions: list[str] = Field(default_factory=list)
    # True when the user message matched closing / small-talk signals (see rag_service.is_session_closing).
    session_closing: bool = False


class StarterQuestionsResponse(BaseModel):
    questions: list[str]


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
    Returns up to 5 profile-based starter questions as chips when the chat opens.
    Falls back inside rag_service if the model is unavailable.
    """
    db = await get_database()
    user_profile, pantry_items = await _fetch_user_profile_and_pantry(db, user_id)
    questions = rag_service.generate_starter_questions(user_profile, pantry_items)
    return StarterQuestionsResponse(questions=questions)


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
    if not body.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    db = await get_database()
    user_profile, pantry_items = await _fetch_user_profile_and_pantry(db, user_id)

    history = [{"role": t.role, "parts": t.parts} for t in body.history]

    try:
        response_text = await rag_service.chat(
            message=body.message,
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

    # Cheap check first: skip follow-up generation entirely on closing turns.
    if is_session_closing(body.message):
        return ChatResponse(
            response=response_text,
            follow_up_questions=[],
            session_closing=True,
        )

    follow_ups: list[str] = []
    if should_suggest_follow_ups(response_text):
        try:
            follow_ups = rag_service.generate_follow_up_questions(
                original_question=body.message,
                answer=response_text,
                user_profile=user_profile,
            )
        except Exception as exc:
            logger.warning("Follow-up generation skipped for user %s: %s", user_id, exc)

    return ChatResponse(
        response=response_text,
        follow_up_questions=follow_ups,
        session_closing=False,
    )
