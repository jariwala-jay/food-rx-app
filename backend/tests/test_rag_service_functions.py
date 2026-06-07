"""
Unit tests for pure functions in rag_service.py and chatbot.py.

No API calls — tests only deterministic logic.

Run from backend/:
    python3 -m pytest tests/test_rag_service_functions.py -v
"""

import sys
import unittest
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.services.rag_service import (
    _cosine,
    _infer_kb_categories,
    _resolve_plan_for_profile,
    _strip_llm_ui_phrases,
    _build_rag_user_message,
    should_suggest_follow_ups,
    build_chunks,
    _chunk_doc,
    RAGService,
)
from app.routers.chatbot import (
    _rag_category_label,
    _is_generic_meal_scope_query,
    _all_conditions,
    _primary_condition_multi,
)

# ── _cosine ───────────────────────────────────────────────────────────────────


class TestCosine(unittest.TestCase):

    def test_identical_vectors_return_one(self):
        v = [1.0, 0.0, 0.0]
        self.assertAlmostEqual(_cosine(v, v), 1.0, places=5)

    def test_orthogonal_vectors_return_zero(self):
        a = [1.0, 0.0]
        b = [0.0, 1.0]
        self.assertAlmostEqual(_cosine(a, b), 0.0, places=5)

    def test_opposite_vectors_return_negative_one(self):
        a = [1.0, 0.0]
        b = [-1.0, 0.0]
        self.assertAlmostEqual(_cosine(a, b), -1.0, places=5)

    def test_zero_vector_returns_zero(self):
        a = [0.0, 0.0]
        b = [1.0, 0.0]
        self.assertEqual(_cosine(a, b), 0.0)

    def test_both_zero_vectors_return_zero(self):
        self.assertEqual(_cosine([0.0, 0.0], [0.0, 0.0]), 0.0)

    def test_partial_similarity(self):
        a = [1.0, 1.0]
        b = [1.0, 0.0]
        result = _cosine(a, b)
        self.assertGreater(result, 0.0)
        self.assertLess(result, 1.0)


# ── _resolve_plan_for_profile ─────────────────────────────────────────────────


class TestResolvePlanForProfile(unittest.TestCase):

    def test_diabetes_condition_returns_diabetes_plate(self):
        profile = {"medicalConditions": ["diabetes"]}
        self.assertEqual(_resolve_plan_for_profile(profile), "DiabetesPlate")

    def test_prediabetes_condition_returns_diabetes_plate(self):
        profile = {"medicalConditions": ["prediabetes"]}
        self.assertEqual(_resolve_plan_for_profile(profile), "DiabetesPlate")

    def test_diabetes_overrides_dash_plan(self):
        profile = {"medicalConditions": ["diabetes"], "myPlanType": "DASH"}
        self.assertEqual(_resolve_plan_for_profile(profile), "DiabetesPlate")

    def test_hypertension_only_returns_dash(self):
        profile = {"medicalConditions": ["hypertension"]}
        self.assertEqual(_resolve_plan_for_profile(profile), "DASH")

    def test_explicit_dash_plan_returns_dash(self):
        profile = {"medicalConditions": [], "myPlanType": "DASH"}
        self.assertEqual(_resolve_plan_for_profile(profile), "DASH")

    def test_explicit_myplate_plan_returns_myplate(self):
        profile = {"medicalConditions": [], "myPlanType": "MyPlate"}
        self.assertEqual(_resolve_plan_for_profile(profile), "MyPlate")

    def test_no_conditions_no_plan_returns_myplate(self):
        profile = {"medicalConditions": []}
        self.assertEqual(_resolve_plan_for_profile(profile), "MyPlate")

    def test_none_profile_returns_none(self):
        self.assertIsNone(_resolve_plan_for_profile(None))

    def test_non_dict_returns_none(self):
        self.assertIsNone(_resolve_plan_for_profile("not a dict"))

    def test_obesity_only_returns_myplate(self):
        profile = {"medicalConditions": ["obesity"]}
        self.assertEqual(_resolve_plan_for_profile(profile), "MyPlate")

    def test_diabetes_and_hypertension_returns_diabetes_plate(self):
        """Diabetes always wins over hypertension."""
        profile = {"medicalConditions": ["diabetes", "hypertension"]}
        self.assertEqual(_resolve_plan_for_profile(profile), "DiabetesPlate")

    def test_dash_diet_variant_returns_dash(self):
        profile = {"medicalConditions": [], "myPlanType": "Dash diet"}
        self.assertEqual(_resolve_plan_for_profile(profile), "DASH")

    def test_unknown_plan_with_no_conditions_returns_myplate(self):
        profile = {"medicalConditions": [], "myPlanType": "CustomPlan123"}
        self.assertEqual(_resolve_plan_for_profile(profile), "MyPlate")


# ── _infer_kb_categories ──────────────────────────────────────────────────────


class TestInferKbCategories(unittest.TestCase):

    def test_sleep_keyword_returns_sleep(self):
        result = _infer_kb_categories("How can I sleep better?")
        self.assertIn("sleep", result)

    def test_insomnia_returns_sleep(self):
        result = _infer_kb_categories("I have insomnia, what should I eat?")
        self.assertIn("sleep", result)

    def test_blood_pressure_returns_hypertension(self):
        result = _infer_kb_categories("What foods lower blood pressure?")
        self.assertIn("hypertension", result)

    def test_sodium_returns_hypertension(self):
        result = _infer_kb_categories("How much sodium should I have daily?")
        self.assertIn("hypertension", result)

    def test_diabetes_returns_diabetes(self):
        result = _infer_kb_categories("What foods are good for diabetes?")
        self.assertIn("diabetes", result)

    def test_blood_sugar_returns_diabetes(self):
        result = _infer_kb_categories("How do I manage my blood sugar?")
        self.assertIn("diabetes", result)

    def test_prediabetes_returns_pre_diabetes(self):
        result = _infer_kb_categories("I have prediabetes, what should I eat?")
        self.assertIn("pre-diabetes", result)

    def test_water_returns_hydration(self):
        result = _infer_kb_categories("How much water should I drink daily?")
        self.assertIn("hydration", result)

    def test_weight_loss_returns_obesity(self):
        result = _infer_kb_categories("How do I lose weight?")
        self.assertIn("obesity", result)

    def test_unrelated_query_returns_none(self):
        result = _infer_kb_categories("What is the weather today?")
        self.assertIsNone(result)

    def test_multiple_categories_detected(self):
        result = _infer_kb_categories("How does sleep affect blood sugar?")
        self.assertIn("sleep", result)
        self.assertIn("diabetes", result)

    def test_empty_string_returns_none(self):
        result = _infer_kb_categories("")
        self.assertIsNone(result)


# ── _strip_llm_ui_phrases ─────────────────────────────────────────────────────


class TestStripLlmUiPhrases(unittest.TestCase):

    def test_removes_explore_more_below(self):
        text = "Eat more vegetables.\nYou can explore more below.\nDrink water."
        result = _strip_llm_ui_phrases(text)
        self.assertNotIn("explore more below", result.lower())

    def test_fixes_diabetesplate_to_diabetes_plate(self):
        text = "Follow the DiabetesPlate method."
        result = _strip_llm_ui_phrases(text)
        self.assertIn("Diabetes Plate", result)
        self.assertNotIn("DiabetesPlate", result)

    def test_fixes_you_want_foods_that_help(self):
        text = "You want foods that help manage blood sugar."
        result = _strip_llm_ui_phrases(text)
        self.assertNotIn("You want foods that help", result)
        self.assertIn("These foods help", result)

    def test_normalizes_multiple_blank_lines(self):
        text = "Line one.\n\n\n\nLine two."
        result = _strip_llm_ui_phrases(text)
        self.assertNotIn("\n\n\n", result)

    def test_empty_string_returns_empty(self):
        result = _strip_llm_ui_phrases("")
        self.assertEqual(result, "")

    def test_none_returns_empty(self):
        result = _strip_llm_ui_phrases(None)
        self.assertEqual(result, "")

    def test_clean_text_unchanged(self):
        text = "Eat more fiber-rich foods like oats and vegetables."
        result = _strip_llm_ui_phrases(text)
        self.assertEqual(result, text)


# ── should_suggest_follow_ups ─────────────────────────────────────────────────


class TestShouldSuggestFollowUps(unittest.TestCase):

    def test_long_response_returns_true(self):
        response = (
            "Eating more vegetables helps maintain a healthy weight and provides fiber."
        )
        self.assertTrue(should_suggest_follow_ups(response))

    def test_short_response_returns_false(self):
        self.assertFalse(should_suggest_follow_ups("Too short"))

    def test_empty_string_returns_false(self):
        self.assertFalse(should_suggest_follow_ups(""))

    def test_none_returns_false(self):
        self.assertFalse(should_suggest_follow_ups(None))

    def test_exactly_24_chars_returns_true(self):
        # 24 characters exactly
        self.assertTrue(should_suggest_follow_ups("a" * 24))

    def test_23_chars_returns_false(self):
        self.assertFalse(should_suggest_follow_ups("a" * 23))


# ── _build_rag_user_message ───────────────────────────────────────────────────


class TestBuildRagUserMessage(unittest.TestCase):

    def test_contains_context_and_question(self):
        result = _build_rag_user_message(
            context_from_documents="Fiber slows sugar absorption.",
            question="What is fiber?",
        )
        self.assertIn("Fiber slows sugar absorption.", result)
        self.assertIn("What is fiber?", result)

    def test_portion_question_adds_focus_hint(self):
        result = _build_rag_user_message(
            context_from_documents="Use the plate method.",
            question="What are the portion sizes for the Diabetes Plate?",
        )
        self.assertIn("portion sizes and plate structure", result)

    def test_diabetes_plate_plan_adds_structure_hint(self):
        result = _build_rag_user_message(
            context_from_documents="Fill half with vegetables.",
            question="What should I eat?",
            resolved_plan="DiabetesPlate",
        )
        self.assertIn("Diabetes Plate structure", result)

    def test_no_plan_no_extra_hint(self):
        result = _build_rag_user_message(
            context_from_documents="Eat vegetables.",
            question="What should I eat?",
            resolved_plan=None,
        )
        self.assertNotIn("Diabetes Plate structure", result)

    def test_result_is_string(self):
        result = _build_rag_user_message(
            context_from_documents="Some context.",
            question="Some question?",
        )
        self.assertIsInstance(result, str)


# ── build_chunks and _chunk_doc ───────────────────────────────────────────────


class TestBuildChunks(unittest.TestCase):

    def _make_doc(self, content: str, doc_id: str = "test_doc") -> dict:
        return {
            "id": doc_id,
            "title": "Test Document",
            "category": "General",
            "source": "https://example.com",
            "content": content,
        }

    def test_short_doc_produces_one_chunk(self):
        doc = self._make_doc("This is a short document.")
        chunks = _chunk_doc(doc)
        self.assertEqual(len(chunks), 1)

    def test_chunk_has_required_fields(self):
        doc = self._make_doc("This is a test document with some content.")
        chunks = _chunk_doc(doc)
        required = {
            "doc_id",
            "title",
            "category",
            "source",
            "chunk_index",
            "total_chunks",
            "text",
        }
        for chunk in chunks:
            self.assertEqual(required, set(chunk.keys()))

    def test_chunk_inherits_doc_metadata(self):
        doc = self._make_doc("Some content here.", doc_id="my_doc")
        chunks = _chunk_doc(doc)
        for chunk in chunks:
            self.assertEqual(chunk["doc_id"], "my_doc")
            self.assertEqual(chunk["title"], "Test Document")
            self.assertEqual(chunk["category"], "General")
            self.assertEqual(chunk["source"], "https://example.com")

    def test_chunk_index_starts_at_zero(self):
        doc = self._make_doc("First sentence. Second sentence.")
        chunks = _chunk_doc(doc)
        self.assertEqual(chunks[0]["chunk_index"], 0)

    def test_long_doc_produces_multiple_chunks(self):
        # Generate content longer than CHUNK_MAX_CHARS (1000)
        long_content = " ".join([f"This is sentence number {i}." for i in range(200)])
        doc = self._make_doc(long_content)
        chunks = _chunk_doc(doc)
        self.assertGreater(len(chunks), 1)

    def test_each_chunk_text_non_empty(self):
        doc = self._make_doc("Eat more vegetables. Drink more water. Sleep well.")
        chunks = _chunk_doc(doc)
        for chunk in chunks:
            self.assertGreater(len(chunk["text"].strip()), 0)

    def test_total_chunks_matches_actual_count(self):
        long_content = " ".join([f"Sentence {i}." for i in range(200)])
        doc = self._make_doc(long_content)
        chunks = _chunk_doc(doc)
        for chunk in chunks:
            self.assertEqual(chunk["total_chunks"], len(chunks))

    def test_build_chunks_aggregates_multiple_docs(self):
        docs = [
            self._make_doc("Doc one content.", doc_id="doc1"),
            self._make_doc("Doc two content.", doc_id="doc2"),
        ]
        chunks = build_chunks(docs)
        doc_ids = {c["doc_id"] for c in chunks}
        self.assertIn("doc1", doc_ids)
        self.assertIn("doc2", doc_ids)

    def test_build_chunks_empty_list_returns_empty(self):
        result = build_chunks([])
        self.assertEqual(result, [])


# ── _rag_category_label ───────────────────────────────────────────────────────


class TestRagCategoryLabel(unittest.TestCase):

    def test_sleep_query_returns_sleep(self):
        self.assertEqual(_rag_category_label("How can I sleep better?"), "sleep")

    def test_exercise_query_returns_exercise(self):
        self.assertEqual(
            _rag_category_label("What exercises are safe for me?"), "exercise"
        )

    def test_hydration_query_returns_hydration(self):
        self.assertEqual(
            _rag_category_label("How much water should I drink?"), "hydration"
        )

    def test_diabetes_query_returns_diabetes(self):
        self.assertEqual(
            _rag_category_label("What foods help with blood sugar?"), "diabetes"
        )

    def test_prediabetes_query_returns_diabetes(self):
        self.assertEqual(
            _rag_category_label("I have prediabetes. What should I eat?"), "diabetes"
        )

    def test_hypertension_query_returns_hypertension(self):
        self.assertEqual(
            _rag_category_label("What foods lower blood pressure?"), "hypertension"
        )

    def test_obesity_query_returns_obesity(self):
        self.assertEqual(_rag_category_label("How do I lose weight?"), "obesity")

    def test_unrelated_query_returns_none(self):
        self.assertIsNone(_rag_category_label("What is the weather?"))

    def test_empty_string_returns_none(self):
        self.assertIsNone(_rag_category_label(""))


# ── _is_generic_meal_scope_query ──────────────────────────────────────────────


class TestIsGenericMealScopeQuery(unittest.TestCase):

    def test_what_should_i_eat_is_generic(self):
        self.assertTrue(_is_generic_meal_scope_query("What should I eat?"))

    def test_what_can_i_eat_is_generic(self):
        self.assertTrue(_is_generic_meal_scope_query("What can I eat?"))

    def test_diabetes_query_is_not_generic(self):
        self.assertFalse(
            _is_generic_meal_scope_query("What should I eat for diabetes?")
        )

    def test_sodium_query_is_not_generic(self):
        self.assertFalse(
            _is_generic_meal_scope_query("What should I eat to reduce sodium?")
        )

    def test_sleep_query_is_not_generic(self):
        self.assertFalse(
            _is_generic_meal_scope_query("What should I eat to sleep better?")
        )

    def test_long_query_is_not_generic(self):
        long_query = "What should I eat " + "x" * 120
        self.assertFalse(_is_generic_meal_scope_query(long_query))

    def test_fiber_question_is_not_generic(self):
        self.assertFalse(_is_generic_meal_scope_query("What foods have fiber?"))


# ── _all_conditions ───────────────────────────────────────────────────────────


class TestAllConditions(unittest.TestCase):

    def test_diabetes_condition_normalized(self):
        profile = {"medicalConditions": ["diabetes"]}
        self.assertIn("diabetes", _all_conditions(profile))

    def test_prediabetes_maps_to_diabetes(self):
        profile = {"medicalConditions": ["prediabetes"]}
        self.assertIn("diabetes", _all_conditions(profile))

    def test_hypertension_normalized(self):
        profile = {"medicalConditions": ["hypertension"]}
        self.assertIn("hypertension", _all_conditions(profile))

    def test_blood_pressure_maps_to_hypertension(self):
        profile = {"medicalConditions": ["high blood pressure"]}
        self.assertIn("hypertension", _all_conditions(profile))

    def test_obesity_normalized(self):
        profile = {"medicalConditions": ["obesity"]}
        self.assertIn("obesity", _all_conditions(profile))

    def test_overweight_maps_to_obesity(self):
        profile = {"medicalConditions": ["overweight"]}
        self.assertIn("obesity", _all_conditions(profile))

    def test_none_profile_returns_empty(self):
        self.assertEqual(_all_conditions(None), [])

    def test_empty_conditions_returns_empty(self):
        profile = {"medicalConditions": []}
        self.assertEqual(_all_conditions(profile), [])

    def test_multiple_conditions_all_normalized(self):
        profile = {"medicalConditions": ["diabetes", "hypertension"]}
        result = _all_conditions(profile)
        self.assertIn("diabetes", result)
        self.assertIn("hypertension", result)

    def test_conditions_key_alias(self):
        """Both 'conditions' and 'medicalConditions' keys are supported."""
        profile = {"conditions": ["diabetes"]}
        self.assertIn("diabetes", _all_conditions(profile))


# ── _primary_condition_multi ──────────────────────────────────────────────────


class TestPrimaryConditionMulti(unittest.TestCase):

    def test_diabetes_is_primary(self):
        self.assertEqual(
            _primary_condition_multi(["diabetes", "hypertension"]), "diabetes"
        )

    def test_hypertension_is_primary_when_no_diabetes(self):
        self.assertEqual(
            _primary_condition_multi(["hypertension", "obesity"]), "hypertension"
        )

    def test_obesity_is_primary_when_only_condition(self):
        self.assertEqual(_primary_condition_multi(["obesity"]), "obesity")

    def test_empty_list_returns_none(self):
        self.assertIsNone(_primary_condition_multi([]))

    def test_unknown_condition_returns_none(self):
        self.assertIsNone(_primary_condition_multi(["unknown_condition"]))

    def test_diabetes_beats_obesity(self):
        self.assertEqual(_primary_condition_multi(["obesity", "diabetes"]), "diabetes")


# ── _build_user_context ───────────────────────────────────────────────────────


class TestBuildUserContext(unittest.TestCase):

    def test_empty_profile_returns_empty_string(self):
        result = RAGService._build_user_context(None, [])
        self.assertEqual(result, "")

    def test_includes_resolved_plan(self):
        profile = {"medicalConditions": ["diabetes"]}
        result = RAGService._build_user_context(profile, [])
        self.assertIn("DiabetesPlate", result)

    def test_includes_conditions(self):
        profile = {"medicalConditions": ["diabetes", "hypertension"]}
        result = RAGService._build_user_context(profile, [])
        self.assertIn("diabetes", result)

    def test_includes_allergies(self):
        profile = {"medicalConditions": [], "allergies": ["peanuts", "shellfish"]}
        result = RAGService._build_user_context(profile, [])
        self.assertIn("peanuts", result)

    def test_includes_first_name(self):
        profile = {"medicalConditions": [], "name": "Alice Smith"}
        result = RAGService._build_user_context(profile, [])
        self.assertIn("Alice", result)

    def test_includes_pantry_items(self):
        profile = {"medicalConditions": []}
        pantry = [{"name": "broccoli"}, {"name": "chicken"}]
        result = RAGService._build_user_context(profile, pantry)
        self.assertIn("broccoli", result)

    def test_includes_calorie_target(self):
        profile = {"medicalConditions": [], "targetCalories": 1800}
        result = RAGService._build_user_context(profile, [])
        self.assertIn("1800", result)

    def test_includes_health_goals(self):
        profile = {"medicalConditions": [], "healthGoals": ["lose weight"]}
        result = RAGService._build_user_context(profile, [])
        self.assertIn("lose weight", result)


if __name__ == "__main__":
    unittest.main()
