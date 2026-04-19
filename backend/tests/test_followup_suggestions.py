from pathlib import Path
import sys
import unittest

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.routers.chatbot import _generate_suggestions


def _run(query: str, profile: dict, response: str | None = None) -> list[str]:
    return _generate_suggestions(
        query=query,
        response=response or "Here are practical food and nutrition suggestions for your goals.",
        user_profile=profile,
        user_id="test_user",
        conversation_id="test_conv",
    )


class TestFollowupSuggestions(unittest.TestCase):
    def test_diabetes_hypertension_combo_is_plan_aware(self) -> None:
        profile = {
            "medicalConditions": ["diabetes", "hypertension"],
            "myPlanType": "Diabetes Plate",
        }
        result = _run("What should I eat?", profile)
        self.assertEqual(
            result,
            [
                "What foods fit the Diabetes Plate and are low in salt?",
                "Can you show a low-salt Diabetes Plate meal plan?",
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
                "What foods help control my blood sugar?",
                "Can you suggest a simple diabetes meal plan?",
            ],
        )


    def test_category_applies_when_no_condition_or_plan(self) -> None:
        profile = {"medicalConditions": []}
        result = _run("How can I sleep better?", profile)
        self.assertEqual(
            result,
            [
                "How many hours should I sleep?",
                "How can I improve my sleep quality?",
            ],
        )


    def test_short_response_disables_suggestions(self) -> None:
        profile = {"medicalConditions": ["diabetes"], "myPlanType": "Diabetes Plate"}
        result = _run("What should I eat?", profile, response="Too short")
        self.assertEqual(result, [])


if __name__ == "__main__":
    unittest.main()
