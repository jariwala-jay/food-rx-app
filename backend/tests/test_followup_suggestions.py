from pathlib import Path
import sys
import unittest
import uuid

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.routers.chatbot import _generate_suggestions


def _run(
    query: str,
    profile: dict,
    response: str | None = None,
    *,
    conversation_id: str | None = None,
) -> list[str]:
    # Default: fresh session per call so rotation state does not leak across tests.
    cid = conversation_id if conversation_id is not None else uuid.uuid4().hex
    return _generate_suggestions(
        query=query,
        response=response or "Here are practical food and nutrition suggestions for your goals.",
        user_profile=profile,
        user_id="test_user",
        conversation_id=cid,
    )


class TestFollowupSuggestions(unittest.TestCase):
    def test_diabetes_hypertension_combo_questions_first(self) -> None:
        """Multi-condition users get combination-bank chips before plan-only chips."""
        profile = {
            "medicalConditions": ["diabetes", "hypertension"],
            "myPlanType": "Diabetes Plate",
        }
        result = _run("What should I eat?", profile)
        self.assertEqual(
            result,
            [
                "What foods help control blood sugar and reduce salt?",
                "Can you show a low-salt Diabetes Plate meal?",
            ],
        )

    def test_three_conditions_prefers_combo_priority_order(self) -> None:
        """Diabetes + hypertension wins over other pairs when all three are present."""
        profile = {
            "medicalConditions": ["diabetes", "hypertension", "obesity"],
            "myPlanType": "Diabetes Plate",
        }
        result = _run("What should I eat?", profile)
        self.assertEqual(
            result,
            [
                "What foods help control blood sugar and reduce salt?",
                "Can you show a low-salt Diabetes Plate meal?",
            ],
        )


    def test_plan_first_for_single_condition(self) -> None:
        profile = {"medicalConditions": ["diabetes"], "myPlanType": "Diabetes Plate"}
        result = _run("What should I eat?", profile)
        self.assertEqual(
            result,
            [
                "Can you show a Diabetes Plate meal example?",
                "What foods fit well in the Diabetes Plate?",
            ],
        )


    def test_hypertension_plan_normalization_dash_diet(self) -> None:
        profile = {"medicalConditions": ["hypertension"], "myPlanType": "Dash diet"}
        result = _run("What should I eat?", profile)
        self.assertEqual(
            result,
            [
                "Can you show a DASH-style daily meal plan?",
                "What foods are low in sodium?",
            ],
        )


    def test_obesity_or_none_uses_myplate_when_plan_set(self) -> None:
        profile = {"medicalConditions": [], "myPlanType": "MyPlate"}
        result = _run("What should I eat?", profile)
        self.assertEqual(
            result,
            [
                "Can you show a balanced MyPlate meal?",
                "How do I build a healthy plate?",
            ],
        )


    def test_unknown_plan_falls_back_to_condition(self) -> None:
        profile = {"medicalConditions": ["diabetes"], "myPlanType": "CustomPlan123"}
        result = _run("What should I eat?", profile)
        self.assertEqual(
            result,
            [
                "What foods help keep my blood sugar steady?",
                "What meals are good for blood sugar control?",
            ],
        )


    def test_category_applies_when_no_condition_or_plan(self) -> None:
        profile = {"medicalConditions": []}
        result = _run("How can I sleep better?", profile)
        self.assertEqual(
            result,
            [
                "How many hours should I sleep each night?",
                "How can I improve my sleep quality?",
            ],
        )

    def test_query_topic_beats_plan_for_followups(self) -> None:
        """Glycemic query uses diabetes chip pool even when assigned MyPlate."""
        profile = {"medicalConditions": [], "myPlanType": "MyPlate"}
        result = _run("What is glycemic index?", profile)
        self.assertEqual(
            result,
            [
                "What foods help keep my blood sugar steady?",
                "What meals are good for blood sugar control?",
            ],
        )

    def test_generic_meal_query_keeps_plan_not_topic_bucket(self) -> None:
        """Broad meal questions follow assigned plan chips, not condition/topic banks."""
        profile = {"medicalConditions": [], "myPlanType": "MyPlate"}
        result = _run("What should I eat today?", profile)
        self.assertEqual(
            result,
            [
                "Can you show a balanced MyPlate meal?",
                "How do I build a healthy plate?",
            ],
        )

    def test_fiber_question_stays_plan_not_category(self) -> None:
        """Fiber is general nutrition — follow-ups stay plan-aligned, not condition buckets."""
        profile = {"medicalConditions": [], "myPlanType": "MyPlate"}
        result = _run("What foods have fiber?", profile)
        self.assertEqual(
            result,
            [
                "Can you show a balanced MyPlate meal?",
                "How do I build a healthy plate?",
            ],
        )

    def test_rotation_advances_within_same_conversation(self) -> None:
        profile = {"medicalConditions": [], "myPlanType": "MyPlate"}
        conv = uuid.uuid4().hex
        r1 = _run("What should I eat?", profile, conversation_id=conv)
        r2 = _run("What should I eat?", profile, conversation_id=conv)
        self.assertEqual(len(r1), 2)
        self.assertEqual(len(r2), 2)
        self.assertNotEqual(r1, r2)


    def test_short_response_disables_suggestions(self) -> None:
        profile = {"medicalConditions": ["diabetes"], "myPlanType": "Diabetes Plate"}
        result = _run("What should I eat?", profile, response="Too short")
        self.assertEqual(result, [])

    def test_steady_blood_sugar_foods_chip_pairs_snacks_and_meals(self) -> None:
        """Selecting 'what foods help keep my blood sugar steady' yields snacks + meal follow-ups."""
        profile = {"medicalConditions": ["diabetes"], "myPlanType": "Diabetes Plate"}
        result = _run("What foods help keep my blood sugar steady?", profile)
        self.assertEqual(
            result,
            [
                "What snacks are good for managing my blood sugar?",
                "What meals are good for blood sugar control?",
            ],
        )


if __name__ == "__main__":
    unittest.main()
