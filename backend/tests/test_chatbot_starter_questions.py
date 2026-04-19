import unittest
from pathlib import Path
import sys

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.routers.chatbot import (
    _extract_profile_conditions,
    format_conditions,
    generate_starter_questions,
)


class TestFormatConditions(unittest.TestCase):
    def test_empty_conditions_falls_back_to_default(self) -> None:
        self.assertEqual(format_conditions([]), "my condition")

    def test_single_condition(self) -> None:
        self.assertEqual(format_conditions(["diabetes"]), "diabetes")

    def test_two_conditions(self) -> None:
        self.assertEqual(
            format_conditions(["diabetes", "hypertension"]),
            "diabetes and hypertension",
        )

    def test_three_conditions_uses_oxford_comma(self) -> None:
        self.assertEqual(
            format_conditions(["diabetes", "hypertension", "obesity"]),
            "diabetes, hypertension, and obesity",
        )

    def test_ignores_blank_entries(self) -> None:
        self.assertEqual(
            format_conditions(["  ", "diabetes", "", "hypertension"]),
            "diabetes and hypertension",
        )


class TestGenerateStarterQuestions(unittest.TestCase):
    def test_replaces_condition_placeholder_when_present(self) -> None:
        questions = generate_starter_questions(["diabetes", "hypertension"])
        self.assertEqual(len(questions), 5)
        self.assertEqual(
            questions[0],
            "What foods are best for managing my diabetes and hypertension?",
        )
        self.assertEqual(
            questions[1],
            "What diet changes should I follow for diabetes and hypertension?",
        )
        self.assertEqual(
            questions[2],
            "What exercises are safe and helpful for diabetes and hypertension?",
        )

    def test_uses_default_condition_when_missing(self) -> None:
        questions = generate_starter_questions([])
        self.assertIn("my condition", questions[0])
        self.assertIn("my condition", questions[1])
        self.assertIn("my condition", questions[2])

    def test_keeps_non_placeholder_questions_unchanged(self) -> None:
        questions = generate_starter_questions(["diabetes"])
        self.assertEqual(questions[3], "How much water should I drink daily?")
        self.assertEqual(questions[4], "How can I improve my sleep?")

    def test_keeps_question_count_fixed(self) -> None:
        questions = generate_starter_questions(["diabetes"])
        self.assertEqual(len(questions), 5)


class TestExtractProfileConditions(unittest.TestCase):
    def test_prioritizes_conditions_over_medical_conditions(self) -> None:
        profile = {
            "conditions": ["diabetes", "hypertension"],
            "medicalConditions": ["obesity"],
        }
        self.assertEqual(
            _extract_profile_conditions(profile),
            ["diabetes", "hypertension"],
        )

    def test_falls_back_to_medical_conditions(self) -> None:
        profile = {
            "medicalConditions": ["pre-diabetes", "hypertension"],
        }
        self.assertEqual(
            _extract_profile_conditions(profile),
            ["pre-diabetes", "hypertension"],
        )

    def test_handles_string_condition_and_deduplicates(self) -> None:
        profile = {
            "conditions": "diabetes",
            "medicalConditions": ["diabetes", "hypertension"],
        }
        self.assertEqual(_extract_profile_conditions(profile), ["diabetes"])

    def test_returns_empty_for_invalid_profile(self) -> None:
        self.assertEqual(_extract_profile_conditions(None), [])
        self.assertEqual(_extract_profile_conditions({}), [])


if __name__ == "__main__":
    unittest.main()
