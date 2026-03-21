"""
Chatbot router — POST /chatbot/chat

Accepts a user message + optional conversation history and returns a
RAG-generated response personalised to the logged-in user's health profile.
"""

from __future__ import annotations

import logging
from typing import Any

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.database import get_database
from app.deps import get_current_user_id
from app.services.rag_service import rag_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/chatbot", tags=["chatbot"])


# ─── Request / Response schemas ──────────────────────────────────────────────

class HistoryTurn(BaseModel):
    role: str          # "user" or "model"
    parts: list[str]   # message text(s)


class ChatRequest(BaseModel):
    message: str
    history: list[HistoryTurn] = []


class ChatResponse(BaseModel):
    response: str


# ─── Endpoint ────────────────────────────────────────────────────────────────

@router.post("/chat", response_model=ChatResponse)
async def chat(
    body: ChatRequest,
    user_id: str = Depends(get_current_user_id),
) -> ChatResponse:
    """
    Generate a RAG-based chatbot response.

    - Fetches the user's profile (health conditions, diet plan, allergies, goals) from MongoDB.
    - Fetches the user's current pantry items from MongoDB.
    - Passes both into the RAG service for personalised, context-aware generation.
    """
    if not body.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    db = await get_database()

    # Fetch user profile
    user_profile: dict[str, Any] | None = None
    try:
        user_profile = await db["users"].find_one({"_id": ObjectId(user_id)})
    except Exception as exc:
        logger.warning("Could not fetch user profile for %s: %s", user_id, exc)

    # Fetch pantry items (up to 30 most recent)
    pantry_items: list[dict] = []
    try:
        cursor = db["pantry_items"].find({"userId": ObjectId(user_id)}).limit(30)
        pantry_items = await cursor.to_list(length=30)
    except Exception as exc:
        logger.warning("Could not fetch pantry items for %s: %s", user_id, exc)

    # Convert Pydantic history to plain dicts for the RAG service
    history = [{"role": t.role, "parts": t.parts} for t in body.history]

    response_text = await rag_service.chat(
        message=body.message,
        history=history,
        user_profile=user_profile,
        pantry_items=pantry_items,
    )

    return ChatResponse(response=response_text)
