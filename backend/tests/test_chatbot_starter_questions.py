import unittest
from pathlib import Path
import sys

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.routers.question_banks import (
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
    def test_always_returns_five_questions(self) -> None:
        questions = generate_starter_questions(
            ["diabetes"], {"medicalConditions": ["diabetes"]}
        )
        self.assertEqual(len(questions), 5)

    def test_returns_five_without_profile(self) -> None:
        questions = generate_starter_questions([])
        self.assertEqual(len(questions), 5)

    def test_diabetes_profile_draws_from_diabetesplate_pool(self) -> None:
        from app.routers.question_banks import STARTER_QUESTION_POOLS

        profile = {"medicalConditions": ["diabetes"]}
        questions = generate_starter_questions(["diabetes"], profile)
        pool = set(STARTER_QUESTION_POOLS["DiabetesPlate"])
        for q in questions:
            self.assertIn(
                q, pool, f"Unexpected question not in DiabetesPlate pool: {q}"
            )

    def test_hypertension_profile_draws_from_dash_pool(self) -> None:
        from app.routers.question_banks import STARTER_QUESTION_POOLS

        profile = {"medicalConditions": ["hypertension"]}
        questions = generate_starter_questions(["hypertension"], profile)
        pool = set(STARTER_QUESTION_POOLS["DASH"])
        for q in questions:
            self.assertIn(q, pool, f"Unexpected question not in DASH pool: {q}")

    def test_no_condition_draws_from_myplate_pool(self) -> None:
        from app.routers.question_banks import STARTER_QUESTION_POOLS

        profile = {"myPlanType": "MyPlate"}
        questions = generate_starter_questions([], profile)
        pool = set(STARTER_QUESTION_POOLS["MyPlate"])
        for q in questions:
            self.assertIn(q, pool, f"Unexpected question not in MyPlate pool: {q}")

    def test_shuffle_produces_variety_across_sessions(self) -> None:
        """Same profile → same pool, but different order across enough calls."""
        profile = {"medicalConditions": ["diabetes"]}
        results = [
            tuple(generate_starter_questions(["diabetes"], profile)) for _ in range(20)
        ]
        # Pool is large enough that 20 draws should not all be identical.
        self.assertGreater(len(set(results)), 1)

    def test_diabetes_overrides_myplate_plan(self) -> None:
        """Diabetes condition always wins over an explicit MyPlate plan type."""
        from app.routers.question_banks import STARTER_QUESTION_POOLS

        profile = {"medicalConditions": ["diabetes"], "myPlanType": "MyPlate"}
        questions = generate_starter_questions(["diabetes"], profile)
        pool = set(STARTER_QUESTION_POOLS["DiabetesPlate"])
        for q in questions:
            self.assertIn(q, pool)

    def test_prediabetes_only_draws_from_prediabetes_pool(self) -> None:
        """Prediabetes-only users get the prevention-framed PreDiabetes pool."""
        from app.routers.question_banks import STARTER_QUESTION_POOLS

        profile = {"medicalConditions": ["prediabetes"]}
        questions = generate_starter_questions(["prediabetes"], profile)
        self.assertEqual(len(questions), 5)
        pool = set(STARTER_QUESTION_POOLS["PreDiabetes"])
        for q in questions:
            self.assertIn(q, pool, f"Unexpected question not in PreDiabetes pool: {q}")

    def test_prediabetes_pool_has_no_diabetes_plate_references(self) -> None:
        """Prevention pool should not mention 'Diabetes Plate' — wrong framing for prediabetes."""
        from app.routers.question_banks import STARTER_QUESTION_POOLS

        for q in STARTER_QUESTION_POOLS["PreDiabetes"]:
            self.assertNotIn(
                "Diabetes Plate",
                q,
                f"PreDiabetes pool question references Diabetes Plate: {q}",
            )

    def test_full_diabetes_overrides_prediabetes_routing(self) -> None:
        """When both diabetes and prediabetes are present, DiabetesPlate wins."""
        from app.routers.question_banks import STARTER_QUESTION_POOLS

        profile = {"medicalConditions": ["diabetes", "prediabetes"]}
        questions = generate_starter_questions(["diabetes", "prediabetes"], profile)
        pool = set(STARTER_QUESTION_POOLS["DiabetesPlate"])
        for q in questions:
            self.assertIn(q, pool)


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
