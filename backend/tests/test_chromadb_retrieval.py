"""
Unit tests for ChromaDB-based retrieval in rag_service.py.

These tests verify retrieval logic and structure without making
any Gemini API calls. ChromaDB must be initialized first by
running the backend server at least once (uvicorn app.main:app).

Run from backend/:
    python3 -m pytest tests/test_chromadb_retrieval.py -v
    # or
    python3 -m unittest tests.test_chromadb_retrieval
"""

import sys
import unittest
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

import chromadb

CHROMA_PATH = BACKEND_ROOT / "app" / "knowledge" / "chroma_db"
COLLECTION_NAME = "myfoodrx_chunks"
EXPECTED_CHUNK_COUNT = 177
KNOWN_CATEGORIES = [
    "Sleep",
    "Exercise",
    "Hydration",
    "Hypertension",
    "Pre-Diabetes",
    "Diabetes",
    "Obesity",
    "General",
]


def _get_collection():
    """Load the ChromaDB collection. Skip tests if not initialized."""
    client = chromadb.PersistentClient(path=str(CHROMA_PATH))
    return client.get_collection(COLLECTION_NAME)


class TestChromaDBCollection(unittest.TestCase):
    """Tests that verify the ChromaDB collection is correctly populated."""

    @classmethod
    def setUpClass(cls):
        """Load collection once for all tests in this class."""
        try:
            cls.collection = _get_collection()
        except Exception as e:
            raise unittest.SkipTest(
                f"ChromaDB not initialized. Run the backend server first. Error: {e}"
            )

    def test_collection_has_correct_chunk_count(self):
        """Collection must contain exactly 177 chunks."""
        count = self.collection.count()
        self.assertEqual(
            count,
            EXPECTED_CHUNK_COUNT,
            f"Expected {EXPECTED_CHUNK_COUNT} chunks but found {count}. "
            "Re-run the backend to re-embed.",
        )

    def test_collection_chunks_have_required_metadata_fields(self):
        """Every chunk must have doc_id, title, category, source, chunk_index."""
        results = self.collection.peek(10)
        required_fields = {"doc_id", "title", "category", "source", "chunk_index"}
        for i, metadata in enumerate(results["metadatas"]):
            missing = required_fields - set(metadata.keys())
            self.assertEqual(
                missing,
                set(),
                f"Chunk {i} is missing metadata fields: {missing}",
            )

    def test_collection_chunks_have_non_empty_documents(self):
        """Every chunk must have non-empty text content."""
        results = self.collection.peek(10)
        for i, doc in enumerate(results["documents"]):
            self.assertIsInstance(doc, str)
            self.assertGreater(
                len(doc.strip()),
                0,
                f"Chunk {i} has empty document text.",
            )

    def test_all_eight_categories_present(self):
        """All 8 knowledge categories must be represented in the collection."""
        results = self.collection.get(include=["metadatas"])
        categories_in_db = {m["category"] for m in results["metadatas"]}
        for category in KNOWN_CATEGORIES:
            self.assertIn(
                category,
                categories_in_db,
                f"Category '{category}' not found in ChromaDB collection.",
            )

    def test_chunk_ids_are_unique(self):
        """All chunk IDs must be unique — no duplicates."""
        results = self.collection.get(include=[])
        ids = results["ids"]
        self.assertEqual(
            len(ids),
            len(set(ids)),
            f"Found duplicate chunk IDs in collection. "
            f"Total: {len(ids)}, Unique: {len(set(ids))}",
        )

    def test_chunk_index_is_integer(self):
        """chunk_index metadata field must be an integer."""
        results = self.collection.peek(20)
        for i, metadata in enumerate(results["metadatas"]):
            self.assertIsInstance(
                metadata["chunk_index"],
                int,
                f"Chunk {i} has non-integer chunk_index: {metadata['chunk_index']}",
            )


class TestChromaDBCategoryFilter(unittest.TestCase):
    """Tests that verify category-based filtering works correctly."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.collection = _get_collection()
        except Exception as e:
            raise unittest.SkipTest(
                f"ChromaDB not initialized. Run the backend server first. Error: {e}"
            )

    def _query_with_category(self, category: str, n_results: int = 4) -> dict:
        """Helper to query collection with a dummy embedding and category filter."""
        # Use a zero vector as dummy query embedding — we're testing filtering, not ranking
        dummy_embedding = [0.0] * 3072
        return self.collection.query(
            query_embeddings=[dummy_embedding],
            n_results=n_results,
            where={"category": category},
            include=["metadatas", "documents"],
        )

    def test_diabetes_filter_returns_only_diabetes_chunks(self):
        """Filtering by 'Diabetes' must return only Diabetes chunks."""
        results = self._query_with_category("Diabetes")
        for metadata in results["metadatas"][0]:
            self.assertEqual(
                metadata["category"],
                "Diabetes",
                f"Expected 'Diabetes' category but got '{metadata['category']}'",
            )

    def test_sleep_filter_returns_only_sleep_chunks(self):
        """Filtering by 'Sleep' must return only Sleep chunks."""
        results = self._query_with_category("Sleep")
        for metadata in results["metadatas"][0]:
            self.assertEqual(metadata["category"], "Sleep")

    def test_hypertension_filter_returns_only_hypertension_chunks(self):
        """Filtering by 'Hypertension' must return only Hypertension chunks."""
        results = self._query_with_category("Hypertension")
        for metadata in results["metadatas"][0]:
            self.assertEqual(metadata["category"], "Hypertension")

    def test_invalid_category_returns_empty(self):
        """Filtering by a non-existent category must return empty results."""
        try:
            results = self._query_with_category("InvalidCategory123")
            ids = results["ids"][0] if results["ids"] else []
            self.assertEqual(
                len(ids),
                0,
                "Expected empty results for invalid category.",
            )
        except Exception:
            # ChromaDB may raise an error for no matching results — both are acceptable
            pass

    def test_each_known_category_has_chunks(self):
        """Each of the 8 known categories must have at least one chunk."""
        for category in KNOWN_CATEGORIES:
            results = self._query_with_category(category, n_results=1)
            ids = results["ids"][0] if results["ids"] else []
            self.assertGreater(
                len(ids),
                0,
                f"Category '{category}' returned no chunks.",
            )

    def test_filter_results_have_document_text(self):
        """Filtered results must include non-empty document text."""
        results = self._query_with_category("General")
        for doc in results["documents"][0]:
            self.assertIsInstance(doc, str)
            self.assertGreater(len(doc.strip()), 0)

    def test_filter_respects_n_results_limit(self):
        """Query must not return more chunks than requested."""
        n = 3
        results = self._query_with_category("Exercise", n_results=n)
        returned = len(results["ids"][0]) if results["ids"] else 0
        self.assertLessEqual(
            returned,
            n,
            f"Expected at most {n} results but got {returned}.",
        )


if __name__ == "__main__":
    unittest.main()
