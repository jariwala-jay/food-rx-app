"""
Unit tests for app.database.ensure_indexes_in_background: index setup must run
off the readiness path, retry only connectivity failures, and never raise.

Uses a fake db, so no MongoDB is needed.

Run:
    cd backend && python3 -m unittest tests.test_background_index_creation -v
"""

from __future__ import annotations

import asyncio
import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from pymongo.errors import NetworkTimeout, OperationFailure, ServerSelectionTimeoutError  # noqa: E402

import app.database as database  # noqa: E402

_ALL_COLLECTIONS = ["rag_response_cache", "refreshTokens", "security_events"]


class _FakeCollection:
    def __init__(self, calls: list, failures: list):
        self._calls = calls
        self._failures = failures

    async def create_index(self, keys, **options):
        self._calls.append((keys, options))
        failure = self._failures.pop(0) if self._failures else None
        if failure:
            raise failure


class _FakeDb:
    def __init__(self, failures: dict | None = None):
        self.calls: dict[str, list] = {}
        self._failures = failures or {}

    def __getitem__(self, name):
        return _FakeCollection(
            self.calls.setdefault(name, []), self._failures.setdefault(name, [])
        )

    def total_calls(self) -> int:
        return sum(len(v) for v in self.calls.values())


class BackgroundIndexCreationTest(unittest.IsolatedAsyncioTestCase):
    async def _run(self, db: _FakeDb, delays=(0, 0, 0)) -> None:
        with patch.object(database.settings, "mongodb_url", "mongodb://stub/db"), patch.object(
            database, "get_database", AsyncMock(return_value=db)
        ), patch.object(database, "_INDEX_RETRY_DELAYS", delays):
            await database.ensure_indexes_in_background()

    async def test_all_steps_attempted_on_success(self):
        db = _FakeDb()
        await self._run(db)
        self.assertEqual(sorted(db.calls), _ALL_COLLECTIONS)
        self.assertEqual(db.total_calls(), 5)
        self.assertEqual(
            db.calls["refreshTokens"][0], ("tokenHash", {"unique": True})
        )
        self.assertEqual(
            db.calls["rag_response_cache"][0][1], {"name": "rag_cache_user_query_condition"}
        )
        self.assertEqual(
            db.calls["security_events"][0],
            ([("timestamp", -1), ("event_type", 1)], {"name": "security_events_time_type"}),
        )

    async def test_permanent_failure_is_not_retried_and_does_not_block_others(self):
        db = _FakeDb({"security_events": [OperationFailure("IndexOptionsConflict")]})
        await self._run(db)
        self.assertEqual(len(db.calls["security_events"]), 1)
        self.assertEqual(len(db.calls["refreshTokens"]), 3)
        self.assertEqual(len(db.calls["rag_response_cache"]), 1)

    async def test_connectivity_failure_defers_remaining_steps_then_retries(self):
        db = _FakeDb({"rag_response_cache": [NetworkTimeout("timed out")]})
        await self._run(db)
        # Failed once, succeeded on the retry; later steps ran only after it.
        self.assertEqual(len(db.calls["rag_response_cache"]), 2)
        self.assertEqual(len(db.calls["security_events"]), 1)
        self.assertEqual(len(db.calls["refreshTokens"]), 3)

    async def test_gives_up_after_bounded_retries_without_raising(self):
        db = _FakeDb({"rag_response_cache": [ServerSelectionTimeoutError("down")] * 10})
        await self._run(db)
        # Initial attempt + one per retry delay.
        self.assertEqual(len(db.calls["rag_response_cache"]), 4)
        self.assertNotIn("security_events", db.calls)

    async def test_cancellation_propagates(self):
        db = _FakeDb({"rag_response_cache": [ServerSelectionTimeoutError("down")] * 10})
        with patch.object(database.settings, "mongodb_url", "mongodb://stub/db"), patch.object(
            database, "get_database", AsyncMock(return_value=db)
        ):
            task = asyncio.create_task(database.ensure_indexes_in_background())
            await asyncio.sleep(0.05)  # now sleeping in the first backoff
            task.cancel()
            result = await asyncio.gather(task, return_exceptions=True)
        self.assertIsInstance(result[0], asyncio.CancelledError)

    async def test_noop_without_mongodb_url(self):
        db = _FakeDb()
        with patch.object(database.settings, "mongodb_url", ""), patch.object(
            database, "get_database", AsyncMock(return_value=db)
        ):
            await database.ensure_indexes_in_background()
        self.assertEqual(db.total_calls(), 0)

    async def test_blocking_ensure_database_indexes_still_attempts_all_steps(self):
        db = _FakeDb({"security_events": [OperationFailure("conflict")]})
        with patch.object(database.settings, "mongodb_url", "mongodb://stub/db"), patch.object(
            database, "get_database", AsyncMock(return_value=db)
        ):
            await database.ensure_database_indexes()
        self.assertEqual(sorted(db.calls), _ALL_COLLECTIONS)
        self.assertEqual(db.total_calls(), 5)


if __name__ == "__main__":
    unittest.main()
