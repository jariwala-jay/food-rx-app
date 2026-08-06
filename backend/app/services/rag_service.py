"""
RAG service — MyFoodRx chatbot.

Uses the google-genai SDK for Gemini embeddings and generation.
Three-layer guard: keyword pre-filter → similarity threshold → hardened system prompt.

VECTOR STORE: Knowledge chunks are embedded once using Gemini and stored persistently
in ChromaDB (``backend/app/knowledge/chroma_db/``). Restarts skip re-embedding when
the collection fingerprint (chunk count + SHA-256 content hash + embedding model)
matches. The collection is rebuilt automatically when the knowledge base or model changes.

Structure
---------
This file is a thin facade. The implementation lives in:
  app/services/rag/constants.py       — thresholds, patterns, message strings
  app/services/rag/security.py        — rate limiting, injection detection, audit logging
  app/services/rag/response_helpers.py — LLM response parsing, phrase stripping
  app/services/rag/profile_helpers.py — plan resolution, KB categories, multi-condition notes
  app/services/rag/query_classifier.py — query classification, polite-chat detection
  app/services/rag/chunker.py         — vector math, sentence splitting, chunking
  app/services/rag/cache.py           — RAG response cache (exact + embedding)
  app/services/rag/prompt_builder.py  — system prompt, RAG user-message construction

All existing import sites (chatbot.py, suggestion_engine.py, tests) are unchanged.
"""

from __future__ import annotations

import asyncio
import logging
import re
from pathlib import Path
from typing import Any

import chromadb
from google import genai
from google.genai import types
from google.genai.errors import ClientError

try:
    from groq import Groq as _GroqClient
    _GROQ_AVAILABLE = True
except ImportError:
    _GroqClient = None  # type: ignore[assignment,misc]
    _GROQ_AVAILABLE = False

from app.config import settings
from app.knowledge.food_knowledge import KNOWLEDGE_DOCS

# ---------------------------------------------------------------------------
# Submodule imports (also serve as facade re-exports)
# ---------------------------------------------------------------------------

from app.services.rag.constants import (  # noqa: F401 (re-exported)
    CHUNK_MAX_CHARS,
    CHUNK_OVERLAP_SENTENCES,
    COLLECTION_NAME,
    EMBEDDING_DIM_FALLBACK,
    EMBEDDING_MODEL,
    GENERATION_MODELS,
    GROQ_FALLBACK_MODEL,
    LLM_MAX_OUTPUT_TOKENS,
    LLM_TEMPERATURE,
    MAX_HISTORY,
    MAX_INPUT_CHARS,
    MIN_RELEVANCE,
    MIN_RELEVANCE_DIET_WHITELIST,
    MIN_RELEVANCE_TOPIC,
    MIN_RELEVANCE_TOPIC_SLEEP,
    PLAN_INFO,
    RAG_CACHE_COLLECTION,
    RAG_CACHE_EMBED_SCAN_LIMIT,
    RAG_CACHE_EMBED_SIMILARITY_ENABLED,
    RAG_CACHE_EMBED_THRESHOLD,
    RAG_CACHE_VERSION,
    RATE_LIMIT_MAX_MESSAGES,
    RATE_LIMIT_WINDOW_SECONDS,
    RETRIEVAL_CANDIDATES_K,
    RAG_CONTEXT_DOC_COUNT,
    SECURITY_EVENTS_COLLECTION,
    _ALWAYS_ANSWER_PATTERNS,
    _DIET_SIGNALS,
    _EMBED_CHUNK_INTERVAL_SEC,
    _EMBED_MAX_ATTEMPTS,
    _FOLLOWUP_QUERY_PATTERN,
    _HOW_ARE_YOU_NOTE,
    _INJECTION_PATTERNS,
    _MSG_EMERGENCY,
    _MSG_INPUT_TOO_LONG,
    _MSG_LOW_RELEVANCE,
    _MSG_LOW_RELEVANCE_NUTRITION,
    _MSG_MEDICAL,
    _MSG_OFFTOPIC,
    _MSG_RATE_LIMITED,
    _PLAN_QUERY_HINTS,
    _POLITE_CHAT_NOTE,
    _user_message_timestamps,
)
from app.services.rag.security import (  # noqa: F401 (re-exported)
    _contains_embedded_instructions,
    _is_rate_limited,
    _log_rag_audit,
    _log_security_event,
    _looks_like_food_drug_interaction_query,
    _looks_like_medication_decision_query,
)
from app.services.rag.response_helpers import (  # noqa: F401 (re-exported)
    _extract_text_from_generate_response,
    _is_truncation_finish_reason,
    _log_gemini_generation_usage,
    _strip_llm_ui_phrases,
    should_suggest_follow_ups,
)
from app.services.rag.profile_helpers import (  # noqa: F401 (re-exported)
    _build_multi_condition_note,
    _embedding_text_for_retrieval,
    _infer_kb_categories,
    _infer_kb_categories_from_history,
    _is_followup_query,
    _profile_kb_categories,
    _resolve_plan_for_profile,
    _should_apply_multi_condition_overlay,
)
from app.services.rag.query_classifier import (  # noqa: F401 (re-exported)
    _QueryClass,
    _history_to_contents,
    _is_exercise_intent,
    _is_how_are_you_turn,
    _normalize_chat_line,
    _rewrite_lifestyle_scope_refusal,
    _skip_rag_polite_chat,
    classify_query,
    is_polite_chat_turn,
    is_session_closing,
)
from app.services.rag.chunker import (  # noqa: F401 (re-exported)
    _cache_fingerprint,
    _chunks_content_sha256,
    _clean_content,
    _cosine,
    _dot,
    _log_chunk_preview,
    _norm,
    _normalize_content,
    _split_sentences,
    _chunk_doc,
    build_chunks,
)
from app.services.rag.cache import (  # noqa: F401 (re-exported)
    _build_plan_response,
    _cache_plan_key,
    _cache_profile_condition_key,
    _cache_user_key,
    _chunk_matches_condition_priority,
    _is_cache_safe,
    _is_plan_query,
    _normalize_query_for_cache,
    _prioritize_chunks_for_profile,
    _rag_cache_get_exact,
    _rag_cache_get_similar_embedding,
    _rag_cache_put,
    _safe_rag_fallback_response,
    _suggestion_intent_key,
)
from app.services.rag.prompt_builder import (  # noqa: F401 (re-exported)
    SYSTEM_PROMPT,
    _EMBEDDING_FALLBACK_NOTE,
    _EMBEDDING_FALLBACK_NOTE_NUTRITION,
    _build_rag_user_message,
    _clip_text_for_rag_prompt,
    _maybe_append_food_drug_note,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# RAGService class
# ---------------------------------------------------------------------------


class RAGService:
    """Singleton RAG service. Call initialize() once at app startup via lifespan."""

    def __init__(self) -> None:
        self._ready = False
        self._client: genai.Client | None = None
        self._chunks: list[dict[str, str | int]] = []
        self._chromadb_client = None
        self._collection = None

    async def initialize(self) -> None:
        api_key = settings.gemini_api_key
        if not api_key:
            logger.warning(
                "GEMINI_API_KEY not set — chatbot will use fallback responses."
            )
            return
        if not KNOWLEDGE_DOCS:
            logger.warning(
                "KNOWLEDGE_DOCS is empty in food_knowledge.py — add documents before using RAG."
            )
            return

        self._client = genai.Client(api_key=api_key)
        self._chunks = build_chunks(KNOWLEDGE_DOCS)
        _log_chunk_preview(self._chunks, sample_per_doc=2)

        # ── ChromaDB persistent collection ──────────────────────────────
        chroma_path = Path(__file__).parent.parent / "knowledge" / "chroma_db"
        self._chroma_client = chromadb.PersistentClient(path=str(chroma_path))
        current_fp = _cache_fingerprint(self._chunks)

        # Try to load existing collection and verify fingerprint
        try:
            self._collection = self._chroma_client.get_collection(name=COLLECTION_NAME)
            col_meta = self._collection.metadata or {}
            fingerprint_matches = (
                col_meta.get("chunks_sha256") == current_fp["chunks_sha256"]
                and col_meta.get("embedding_model") == current_fp["embedding_model"]
                and col_meta.get("chunk_count") == str(current_fp["count"])
            )
            if fingerprint_matches:
                stored_count = self._collection.count()
                if stored_count == current_fp["count"] and stored_count > 0:
                    logger.info(
                        "ChromaDB fingerprint matches — skipping embedding (%d chunks).",
                        stored_count,
                    )
                    self._ready = True
                    logger.info(
                        "RAG service ready (from ChromaDB) — %d chunks across %d documents.",
                        len(self._chunks),
                        len(KNOWLEDGE_DOCS),
                    )
                    return
                logger.warning(
                    "ChromaDB fingerprint matches but stored count=%d expected=%d — rebuilding.",
                    stored_count,
                    current_fp["count"],
                )
                self._chroma_client.delete_collection(COLLECTION_NAME)
            else:
                logger.info("ChromaDB fingerprint changed — rebuilding collection.")
                self._chroma_client.delete_collection(COLLECTION_NAME)
        except Exception:
            logger.info("ChromaDB collection not found — will create.")

        # Create fresh collection with fingerprint stored in metadata
        self._collection = self._chroma_client.get_or_create_collection(
            name=COLLECTION_NAME,
            metadata={
                "hnsw:space": "cosine",
                "chunks_sha256": current_fp["chunks_sha256"],
                "embedding_model": current_fp["embedding_model"],
                "chunk_count": str(current_fp["count"]),
            },
        )

        # First run — embed all chunks and store in ChromaDB
        logger.info(
            "Embedding %d chunks from %d docs with %s …",
            len(self._chunks),
            len(KNOWLEDGE_DOCS),
            EMBEDDING_MODEL,
        )

        ids: list[str] = []
        embeddings: list[list[float]] = []
        metadatas: list[dict] = []
        documents: list[str] = []

        client = self._client
        assert client is not None
        for idx, chunk in enumerate(self._chunks):
            text = f"{chunk['title']}. {chunk['text']}"
            vec: list[float] | None = None
            for attempt in range(6):
                try:
                    if idx > 0 and attempt == 0:
                        await asyncio.sleep(_EMBED_CHUNK_INTERVAL_SEC)
                    result = client.models.embed_content(
                        model=EMBEDDING_MODEL,
                        contents=text,
                        config=types.EmbedContentConfig(
                            task_type="RETRIEVAL_DOCUMENT",
                        ),
                    )
                    emb_list = result.embeddings or []
                    values = emb_list[0].values if emb_list else None
                    if values:
                        vec = list(values)
                    else:
                        logger.error(
                            "No embedding values for chunk '%s[%s]'",
                            chunk.get("doc_id"),
                            chunk.get("chunk_index"),
                        )
                    break
                except Exception as exc:
                    err_str = str(exc)
                    is_429 = "429" in err_str or "RESOURCE_EXHAUSTED" in err_str
                    if is_429 and attempt < 5:
                        delay = min(120.0, 15.0 * (2**attempt))
                        logger.warning(
                            "Embedding chunk '%s[%s]' rate limited (attempt %s/6), "
                            "retrying in %.0fs…",
                            chunk.get("doc_id"),
                            chunk.get("chunk_index"),
                            attempt + 1,
                            delay,
                        )
                        await asyncio.sleep(delay)
                        continue
                    logger.error(
                        "Failed to embed chunk '%s[%s]': %s",
                        chunk.get("doc_id"),
                        chunk.get("chunk_index"),
                        exc,
                    )
                    break

            final_vec = vec if vec else [0.0] * EMBEDDING_DIM_FALLBACK
            chunk_id = f"{chunk.get('doc_id', 'unknown')}_{idx}"

            ids.append(chunk_id)
            embeddings.append(final_vec)
            metadatas.append(
                {
                    "doc_id": str(chunk.get("doc_id", "")),
                    "title": str(chunk.get("title", "")),
                    "category": str(chunk.get("category", "")),
                    "source": str(chunk.get("source", "")),
                    "chunk_index": int(chunk.get("chunk_index", 0)),
                }
            )
            documents.append(chunk.get("text", ""))

        # Store everything in ChromaDB in one batch
        self._collection.add(
            ids=ids,
            embeddings=embeddings,
            metadatas=metadatas,
            documents=documents,
        )

        self._ready = True
        logger.info(
            "RAG service ready — %d chunks embedded and stored in ChromaDB.",
            len(self._chunks),
        )

    def _retrieve(
        self, query_embedding: list[float]
    ) -> tuple[list[dict[str, str]], float]:
        if self._collection is None or not self._chunks:
            return [], 0.0
        results = self._collection.query(
            query_embeddings=[query_embedding],
            n_results=RETRIEVAL_CANDIDATES_K,
            include=["metadatas", "documents", "distances"],
        )
        if not results["ids"] or not results["ids"][0]:
            return [], 0.0
        # ChromaDB cosine distance = 1 - similarity; convert back
        distances = results["distances"][0]
        best_score = 1.0 - distances[0] if distances else 0.0
        chunks = []
        for meta, doc in zip(results["metadatas"][0], results["documents"][0]):
            chunk = dict(meta)
            chunk["text"] = doc
            chunks.append(chunk)
        return chunks, best_score

    def _retrieve_for_categories(
        self,
        query_embedding: list[float],
        categories_lower: frozenset[str],
    ) -> tuple[list[dict[str, str]], float]:
        """Like _retrieve but only chunks whose category (lowercased) is in the set."""
        if self._collection is None or not self._chunks:
            return [], 0.0
        # Build ChromaDB where filter for categories
        category_list = [
            c.title() for c in categories_lower
        ]  # e.g. ["Sleep", "Diabetes"]
        where = {"category": {"$in": category_list}}
        results = self._collection.query(
            query_embeddings=[query_embedding],
            n_results=RETRIEVAL_CANDIDATES_K,
            where=where,
            include=["metadatas", "documents", "distances"],
        )
        if not results["ids"] or not results["ids"][0]:
            return [], 0.0
        distances = results["distances"][0]
        best_score = 1.0 - distances[0] if distances else 0.0
        chunks = []
        for meta, doc in zip(results["metadatas"][0], results["documents"][0]):
            chunk = dict(meta)
            chunk["text"] = doc
            chunks.append(chunk)
        return chunks, best_score

    @staticmethod
    def _build_user_context(
        user_profile: dict[str, Any] | None,
        pantry_items: list[dict],
    ) -> str:
        if not user_profile:
            return ""

        lines: list[str] = []

        # Optional first name for greeting/closing tone only.
        raw_name = user_profile.get("name")
        if raw_name and str(raw_name).strip():
            first_name = str(raw_name).strip().split()[0]
            first_name = re.sub(r"^[^\w]+|[^\w]+$", "", first_name, flags=re.UNICODE)
            if first_name and len(first_name) <= 48:
                lines.append(
                    f"User first name (optional; use mainly for greeting/closing): {first_name}"
                )

        conditions = (
            user_profile.get("medicalConditions")
            or user_profile.get("conditions")
            or []
        )
        if conditions:
            lines.append(f"Health conditions: {', '.join(str(c) for c in conditions)}")

        allergies = user_profile.get("allergies") or []
        if allergies:
            lines.append(
                f"Food allergies/intolerances: {', '.join(str(a) for a in allergies)}"
            )

        resolved_plan = _resolve_plan_for_profile(user_profile)
        if resolved_plan:
            lines.append(f"Resolved plan (must use exactly this): {resolved_plan}")

        goals = user_profile.get("healthGoals") or []
        if goals:
            lines.append(f"Health goals: {', '.join(str(g) for g in goals)}")

        calories = user_profile.get("targetCalories")
        if calories:
            lines.append(f"Daily calorie target: {calories} kcal")

        if pantry_items:
            items = [str(p.get("name", "")) for p in pantry_items if p.get("name")][:15]
            if items:
                lines.append(f"Current pantry items: {', '.join(items)}")

        return "\n".join(lines)

    def _generate_reply(
        self,
        message: str,
        full_system: str,
        history_contents: list[types.Content],
        *,
        max_output_tokens: int = LLM_MAX_OUTPUT_TOKENS,
        temperature: float = LLM_TEMPERATURE,
    ) -> tuple[str, Any | None, bool, str | None]:
        """Return (text, usage_metadata, truncated, model_used)."""
        client = self._client
        assert client is not None
        last_exc: Exception | None = None
        for model_name in GENERATION_MODELS:
            try:
                chat_session = client.chats.create(
                    model=model_name,
                    config=types.GenerateContentConfig(
                        system_instruction=full_system,
                        max_output_tokens=max_output_tokens,
                        temperature=temperature,
                        response_modalities=["TEXT"],
                        # Without this, 2.5 Flash can spend most of max_output_tokens on
                        # internal reasoning and return MAX_TOKENS with a tiny visible reply.
                        thinking_config=types.ThinkingConfig(thinking_budget=0),
                    ),
                    history=history_contents,
                )
                response = chat_session.send_message(message)
                usage_meta = getattr(response, "usage_metadata", None)
                extracted = _extract_text_from_generate_response(response)
                rt = (getattr(response, "text", None) or "").strip()
                if rt and extracted != rt:
                    logger.debug(
                        "LLM text: aggregated parts len=%d vs response.text len=%d",
                        len(extracted),
                        len(rt),
                    )
                out = _strip_llm_ui_phrases(extracted)
                if not out:
                    logger.error("Empty generation from %s", model_name)
                    return _safe_rag_fallback_response(), None, False, None
                candidates = getattr(response, "candidates", None) or []
                finish_reason = None
                if candidates:
                    finish_reason = getattr(candidates[0], "finish_reason", None)
                fr_str = str(finish_reason) if finish_reason is not None else ""
                truncated = _is_truncation_finish_reason(finish_reason)
                logger.info("LLM finish_reason=%s model=%s", fr_str or "—", model_name)
                if truncated:
                    logger.warning(
                        "LLM output may be truncated (finish_reason=%s, chars=%d, model=%s)",
                        fr_str,
                        len(out),
                        model_name,
                    )
                logger.debug(
                    "LLM reply chars=%d finish_reason=%s",
                    len(out),
                    fr_str or "—",
                )
                if usage_meta is not None:
                    _log_gemini_generation_usage(usage_meta, model_name)
                else:
                    logger.info(
                        "Gemini returned no usage_metadata (model=%s, chars=%d)",
                        model_name,
                        len(out),
                    )
                logger.debug("LLM final response chars=%d", len(out))
                return out, usage_meta, truncated, model_name
            except Exception as exc:
                err_str = str(exc)
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                    logger.warning("Quota hit on %s, trying next model.", model_name)
                    last_exc = exc
                    continue
                code = getattr(exc, "code", None)
                if isinstance(exc, ClientError) and code == 404:
                    logger.warning(
                        "Model not available (%s): %s — trying next model.",
                        model_name,
                        exc,
                    )
                    last_exc = exc
                    continue
                # High demand / transient outage — same as "try another model in the list"
                if code == 503 or "503" in err_str or "UNAVAILABLE" in err_str.upper():
                    logger.warning(
                        "Model overloaded or unavailable (%s): %s — trying next model.",
                        model_name,
                        exc,
                    )
                    last_exc = exc
                    continue
                logger.error("Generation error with %s: %s", model_name, exc)
                return _safe_rag_fallback_response(), None, False, None

        logger.error("All generation models exhausted. Last error: %s", last_exc)

        # ── Groq fallback (llama-3.3-70b) ──────────────────────────────────
        groq_key = settings.groq_api_key
        if _GROQ_AVAILABLE and groq_key:
            try:
                logger.info("Trying Groq fallback (%s).", GROQ_FALLBACK_MODEL)
                groq_client = _GroqClient(api_key=groq_key)
                # Build message list from Gemini history format.
                groq_messages: list[dict[str, str]] = [
                    {"role": "system", "content": full_system}
                ]
                for turn in history_contents:
                    role = "assistant" if turn.role == "model" else "user"
                    text = " ".join(
                        p.text for p in (turn.parts or []) if getattr(p, "text", None)
                    ).strip()
                    if text:
                        groq_messages.append({"role": role, "content": text})
                groq_messages.append({"role": "user", "content": message})
                completion = groq_client.chat.completions.create(
                    model=GROQ_FALLBACK_MODEL,
                    messages=groq_messages,
                    max_tokens=max_output_tokens,
                    temperature=temperature,
                )
                out = _strip_llm_ui_phrases(
                    (completion.choices[0].message.content or "").strip()
                )
                if out:
                    logger.info(
                        "Groq fallback succeeded (%s, chars=%d).",
                        GROQ_FALLBACK_MODEL,
                        len(out),
                    )
                    return out, None, False, GROQ_FALLBACK_MODEL
            except Exception as groq_exc:
                logger.error("Groq fallback failed: %s", groq_exc)

        return _safe_rag_fallback_response(), None, False, None

    async def chat(
        self,
        message: str,
        history: list[dict[str, Any]],
        user_profile: dict[str, Any] | None = None,
        pantry_items: list[dict] | None = None,
        user_id: str | None = None,
        eval_meta_out: dict[str, Any] | None = None,
    ) -> str:
        audit: dict[str, Any] = {
            "query_class": "unknown",
            "plan": _cache_plan_key(user_profile),
            "condition": _cache_profile_condition_key(user_profile),
            "score": None,
            "cache": "none",
            "blocked": None,
            "chars": 0,
            "model_used": None,
            "retrieved_chunks": [],
        }
        try:
            message = (message or "").strip()

            if len(message) > MAX_INPUT_CHARS:
                audit["blocked"] = "input_too_long"
                reply = _MSG_INPUT_TOO_LONG
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            if user_id and _is_rate_limited(user_id):
                audit["blocked"] = "rate_limit"
                logger.warning("Rate limit exceeded for user %s", user_id)
                await _log_security_event("rate_limit", message, user_id)
                reply = _MSG_RATE_LIMITED
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            if _contains_embedded_instructions(message):
                audit["blocked"] = "embedded_instruction"
                logger.warning(
                    "Embedded instruction pattern detected: %.100s", message
                )
                await _log_security_event("embedded_instruction", message, user_id)
                reply = _MSG_OFFTOPIC
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            query_class = classify_query(message)
            audit["query_class"] = query_class
            if query_class == _QueryClass.EMERGENCY:
                audit["blocked"] = "emergency"
                logger.info("Query blocked: EMERGENCY")
                reply = _MSG_EMERGENCY
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply
            if query_class == _QueryClass.MEDICAL:
                audit["blocked"] = "medical"
                logger.info("Query blocked: MEDICAL")
                reply = _MSG_MEDICAL
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply
            if query_class == _QueryClass.OFF_TOPIC:
                if _INJECTION_PATTERNS.search(message):
                    audit["blocked"] = "prompt_injection"
                    await _log_security_event("prompt_injection", message, user_id)
                else:
                    audit["blocked"] = "off_topic"
                logger.info("Query blocked: OFF_TOPIC")
                reply = _MSG_OFFTOPIC
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            if not self._ready or self._client is None:
                reply = (
                    "I am having trouble connecting right now. Please try again in a moment."
                )
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            history_contents = _history_to_contents(history)
            history_cats = _infer_kb_categories_from_history(history)
            is_followup = _is_followup_query(message)
            user_context = self._build_user_context(user_profile, pantry_items or [])
            query_norm = _normalize_query_for_cache(message)
            condition_key = _cache_profile_condition_key(user_profile)
            user_key = _cache_user_key(user_id)
            plan_key = _cache_plan_key(user_profile)

            if _skip_rag_polite_chat(message):
                logger.info("Polite chat turn — skipping query embedding")
                full_system = SYSTEM_PROMPT
                if user_context:
                    full_system += f"\n\nUSER PROFILE:\n{user_context}"
                full_system += _POLITE_CHAT_NOTE
                if _is_how_are_you_turn(message):
                    full_system += _HOW_ARE_YOU_NOTE
                full_system = _maybe_append_food_drug_note(full_system, message)
                reply, _, _, _ = self._generate_reply(
                    message, full_system, history_contents
                )
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            if _is_plan_query(message):
                plan_response = _build_plan_response(plan_key)
                if plan_response:
                    audit["chars"] = len(plan_response)
                    audit["reply"] = plan_response
                    audit["plan_canned"] = True
                    return plan_response

            cached_exact = await _rag_cache_get_exact(
                query_norm, condition_key, user_key, plan_key
            )
            if cached_exact is not None:
                audit["cache"] = "exact"
                reply = _rewrite_lifestyle_scope_refusal(message, cached_exact)
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            client = self._client
            text_for_embed = _embedding_text_for_retrieval(
                message,
                user_profile,
                is_followup=is_followup,
                history_cats=history_cats,
            )
            query_embedding: list[float] | None = None
            use_embedding_fallback = False
            for attempt in range(_EMBED_MAX_ATTEMPTS):
                try:
                    q_result = client.models.embed_content(
                        model=EMBEDDING_MODEL,
                        contents=text_for_embed,
                        config=types.EmbedContentConfig(task_type="RETRIEVAL_QUERY"),
                    )
                    q_emb = q_result.embeddings or []
                    vec = q_emb[0].values if q_emb else None
                    if vec:
                        query_embedding = list(vec)
                    else:
                        logger.error("Query embedding returned no values")
                        use_embedding_fallback = True
                    break
                except Exception as exc:
                    err_str = str(exc)
                    is_429 = "429" in err_str or "RESOURCE_EXHAUSTED" in err_str
                    if is_429 and attempt < _EMBED_MAX_ATTEMPTS - 1:
                        delay = min(8.0, 2.0**attempt)
                        logger.warning(
                            "Embedding rate limited (attempt %s/%s), retrying in %.1fs…",
                            attempt + 1,
                            _EMBED_MAX_ATTEMPTS,
                            delay,
                        )
                        await asyncio.sleep(delay)
                        continue
                    if is_429:
                        logger.error("Embedding quota exhausted after retries: %s", exc)
                        use_embedding_fallback = True
                    else:
                        logger.error("Embedding error: %s", exc)
                    break

            if query_embedding is None:
                if use_embedding_fallback:
                    logger.warning(
                        "Answering without RAG — embedding unavailable for this request."
                    )
                    full_system = SYSTEM_PROMPT
                    if user_context:
                        full_system += f"\n\nUSER PROFILE:\n{user_context}"
                    if query_class == _QueryClass.DIET:
                        full_system += _EMBEDDING_FALLBACK_NOTE_NUTRITION
                    else:
                        full_system += _EMBEDDING_FALLBACK_NOTE
                    full_system = _maybe_append_food_drug_note(full_system, message)
                    reply, _, _, _ = self._generate_reply(
                        message, full_system, history_contents
                    )
                    reply = _rewrite_lifestyle_scope_refusal(message, reply)
                    audit["chars"] = len(reply)
                    audit["reply"] = reply
                    return reply
                reply = "I am having trouble processing your question. Please try again."
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            if not any(v != 0.0 for v in query_embedding):
                logger.error("Query embedding is all zeros — using no-RAG fallback.")
                query_embedding = None
                use_embedding_fallback = True
                full_system = SYSTEM_PROMPT
                if user_context:
                    full_system += f"\n\nUSER PROFILE:\n{user_context}"
                if query_class == _QueryClass.DIET:
                    full_system += _EMBEDDING_FALLBACK_NOTE_NUTRITION
                else:
                    full_system += _EMBEDDING_FALLBACK_NOTE
                full_system = _maybe_append_food_drug_note(full_system, message)
                reply, _, _, _ = self._generate_reply(
                    message, full_system, history_contents
                )
                reply = _rewrite_lifestyle_scope_refusal(message, reply)
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            topic_cats = _infer_kb_categories(message)
            profile_condition_cats = _profile_kb_categories(user_profile)
            if is_followup and (history_cats or profile_condition_cats):
                combined_cats = history_cats | profile_condition_cats
            elif topic_cats:
                combined_cats = topic_cats | profile_condition_cats
            elif profile_condition_cats:
                combined_cats = frozenset(profile_condition_cats)
            else:
                combined_cats = None

            if combined_cats:
                relevant_docs, best_score = self._retrieve_for_categories(
                    query_embedding, combined_cats
                )
                min_rel = MIN_RELEVANCE_TOPIC
                if topic_cats and "sleep" in topic_cats:
                    min_rel = min(min_rel, MIN_RELEVANCE_TOPIC_SLEEP)
                logger.debug(
                    "Topic-focused retrieval %s: best similarity=%.3f (min=%.2f)",
                    combined_cats,
                    best_score,
                    min_rel,
                )
            else:
                relevant_docs, best_score = self._retrieve(query_embedding)
                min_rel = MIN_RELEVANCE
                logger.debug("Best similarity: %.3f (min=%.2f)", best_score, min_rel)

            if (
                _ALWAYS_ANSWER_PATTERNS.search(message)
                and query_class == _QueryClass.DIET
            ):
                min_rel = MIN_RELEVANCE_DIET_WHITELIST
            if is_followup and query_class == _QueryClass.DIET:
                min_rel = min(min_rel, MIN_RELEVANCE_DIET_WHITELIST)

            audit["score"] = best_score

            # Score of exactly 0.0 with a non-zero embedding means category-filtered
            # retrieval failed — retry unfiltered rather than blocking.
            if best_score == 0.0 and any(v != 0.0 for v in (query_embedding or [])):
                logger.warning(
                    "Zero similarity score detected — possible zero-vector embedding. "
                    "Retrying with unfiltered retrieval."
                )
                relevant_docs, best_score = self._retrieve(query_embedding)
                min_rel = MIN_RELEVANCE
                audit["score"] = best_score

            if (
                best_score == 0.0
                and query_embedding
                and any(v != 0.0 for v in query_embedding)
                and not relevant_docs
            ):
                logger.error(
                    "Retrieval returned no chunks with a valid query embedding — "
                    "ChromaDB may be empty or mismatched. Answering without RAG context."
                )
                full_system = SYSTEM_PROMPT
                if user_context:
                    full_system += f"\n\nUSER PROFILE:\n{user_context}"
                if query_class == _QueryClass.DIET:
                    full_system += _EMBEDDING_FALLBACK_NOTE_NUTRITION
                else:
                    full_system += _EMBEDDING_FALLBACK_NOTE
                full_system = _maybe_append_food_drug_note(full_system, message)
                reply, _, _, _ = self._generate_reply(
                    message, full_system, history_contents
                )
                reply = _rewrite_lifestyle_scope_refusal(message, reply)
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            if best_score < min_rel:
                audit["blocked"] = "low_relevance"
                logger.info(
                    "Query blocked: LOW_RELEVANCE (score=%.3f, min=%.2f)",
                    best_score,
                    min_rel,
                )
                if query_class == _QueryClass.DIET:
                    reply = _MSG_LOW_RELEVANCE_NUTRITION
                else:
                    reply = _MSG_LOW_RELEVANCE
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            cached_vec: str | None = None
            if RAG_CACHE_EMBED_SIMILARITY_ENABLED:
                cached_vec = await _rag_cache_get_similar_embedding(
                    query_embedding,
                    condition_key,
                    user_key,
                    plan_key,
                    message,
                    _suggestion_intent_key(message),
                )
            if cached_vec is not None:
                audit["cache"] = "embedding"
                reply = _rewrite_lifestyle_scope_refusal(message, cached_vec)
                audit["chars"] = len(reply)
                audit["reply"] = reply
                return reply

            prioritized = _prioritize_chunks_for_profile(relevant_docs, user_profile)
            top_docs = prioritized[:RAG_CONTEXT_DOC_COUNT]
            logger.info("Using %d docs for RAG context", len(top_docs))

            knowledge_context = "\n\n".join(
                f"[{chunk['title']} — {chunk['category']} — Source: {chunk['source']}]\n"
                f"{_clip_text_for_rag_prompt(str(chunk.get('text', '')))}"
                for chunk in top_docs
            )

            full_system = SYSTEM_PROMPT
            if user_context:
                full_system += f"\n\nUSER PROFILE:\n{user_context}"
            full_system = _maybe_append_food_drug_note(full_system, message)
            multi_note: str | None = None
            if _should_apply_multi_condition_overlay(message, topic_cats):
                multi_note = _build_multi_condition_note(user_profile)
            rag_user_message = _build_rag_user_message(
                context_from_documents=knowledge_context,
                question=message,
                resolved_plan=plan_key,
                multi_condition_note=multi_note,
            )

            reply, _, truncated, model_used = self._generate_reply(
                rag_user_message, full_system, history_contents
            )
            safe_fb = _safe_rag_fallback_response()
            if (
                reply
                and len(reply.strip()) > 24
                and reply != safe_fb
                and reply != _MSG_LOW_RELEVANCE
                and reply != _MSG_LOW_RELEVANCE_NUTRITION
                and not truncated
            ):
                await _rag_cache_put(
                    query_norm,
                    condition_key,
                    user_key,
                    plan_key,
                    query_embedding,
                    reply,
                    _suggestion_intent_key(message),
                    model_used=model_used,
                )
            elif truncated:
                logger.info("Skipping RAG cache write (truncated LLM output).")
            reply = _rewrite_lifestyle_scope_refusal(message, reply)
            audit["model_used"] = model_used
            audit["retrieved_chunks"] = [
                {
                    "doc_id": str(chunk.get("doc_id", "")),
                    "title": str(chunk.get("title", "")),
                    "category": str(chunk.get("category", "")),
                    "text": str(chunk.get("text", "")),
                }
                for chunk in top_docs
            ]
            audit["chars"] = len(reply)
            audit["reply"] = reply
            return reply
        finally:
            if eval_meta_out is not None:
                eval_meta_out.clear()
                eval_meta_out.update(audit)
            _log_rag_audit(audit)


rag_service = RAGService()
