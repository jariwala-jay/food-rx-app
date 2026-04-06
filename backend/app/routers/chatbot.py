"""
Chatbot router — POST /chatbot/chat

RAG-powered chatbot: loads user profile and pantry from MongoDB, then runs the RAG service.
"""

from __future__ import annotations

import logging
from typing import Any

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.database import get_database
from app.deps import get_current_user_id
from app.services.rag_service import rag_service

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


@router.post("/chat", response_model=ChatResponse)
async def chat(
    body: ChatRequest,
    user_id: str = Depends(get_current_user_id),
) -> ChatResponse:
    if not body.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    db = await get_database()

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

    return ChatResponse(response=response_text)
