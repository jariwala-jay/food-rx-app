from pathlib import Path
import sys
import unittest
import uuid

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.routers.suggestion_engine import _generate_suggestions


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
        response=response
        or "Here are practical food and nutrition suggestions for your goals.",
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

    def test_three_conditions_uses_triple_bank_not_pair(self) -> None:
        """All three conditions → triple bank is served, not the diabetes+hypertension pair."""
        from app.routers.question_banks import COMBINATION_QUESTION_BANK

        profile = {
            "medicalConditions": ["diabetes", "hypertension", "obesity"],
            "myPlanType": "Diabetes Plate",
        }
        result = _run("What should I eat?", profile)
        triple_chips = set(COMBINATION_QUESTION_BANK[("diabetes", "hypertension", "obesity")])
        for chip in result:
            self.assertIn(chip, triple_chips)

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

    def test_unknown_plan_resolves_to_condition_based_plan(self) -> None:
        profile = {"medicalConditions": ["diabetes"], "myPlanType": "CustomPlan123"}
        result = _run("What should I eat?", profile)
        self.assertEqual(
            result,
            [
                "Can you show a Diabetes Plate meal example?",
                "What foods fit well in the Diabetes Plate?",
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

    def test_prediabetes_only_uses_prediabetes_chip_bank(self) -> None:
        """Prediabetes-only profile serves prevention-framed chips, not Diabetes Plate chips."""
        from app.routers.question_banks import QUESTION_BANK

        profile = {"medicalConditions": ["prediabetes"]}
        result = _run("What should I eat?", profile)
        self.assertEqual(len(result), 2)
        prediabetes_chips = set(
            q for lst in QUESTION_BANK["PreDiabetes"].values() for q in lst
        )
        for chip in result:
            self.assertIn(
                chip,
                prediabetes_chips,
                f"Chip '{chip}' is not from the PreDiabetes bank",
            )

    def test_three_conditions_uses_triple_bank(self) -> None:
        """Diabetes + hypertension + obesity uses the dedicated triple-condition bank."""
        from app.routers.question_banks import COMBINATION_QUESTION_BANK

        profile = {
            "medicalConditions": ["diabetes", "hypertension", "obesity"],
            "myPlanType": "Diabetes Plate",
        }
        result = _run("What should I eat?", profile)
        self.assertEqual(len(result), 2)
        triple_chips = set(COMBINATION_QUESTION_BANK[("diabetes", "hypertension", "obesity")])
        for chip in result:
            self.assertIn(
                chip,
                triple_chips,
                f"Chip '{chip}' is not from the triple-condition bank",
            )


class TestBypassCombinationBank(unittest.TestCase):
    """Lifestyle and follow-up queries bypass the multi-condition combination bank."""

    _MULTI_CONDITION_PROFILE = {
        "medicalConditions": ["diabetes", "hypertension"],
        "myPlanType": "Diabetes Plate",
    }

    def _combo_chips(self) -> set[str]:
        from app.routers.question_banks import COMBINATION_QUESTION_BANK
        return set(COMBINATION_QUESTION_BANK[("diabetes", "hypertension")])

    def test_sleep_query_bypasses_combination_bank(self) -> None:
        """'How does sleep affect blood sugar?' must return sleep chips, not food combo chips."""
        from app.routers.question_banks import QUESTION_BANK
        result = _run("How does sleep affect my blood sugar?", self._MULTI_CONDITION_PROFILE)
        self.assertEqual(len(result), 2)
        sleep_chips = set(QUESTION_BANK["sleep"]["general"])
        for chip in result:
            self.assertIn(chip, sleep_chips, f"Expected sleep chip, got: '{chip}'")
        for chip in result:
            self.assertNotIn(chip, self._combo_chips(), f"Combo chip leaked: '{chip}'")

    def test_exercise_query_bypasses_combination_bank(self) -> None:
        """Exercise query for multi-condition user must return exercise chips."""
        from app.routers.question_banks import QUESTION_BANK
        result = _run("What exercises are safe for me?", self._MULTI_CONDITION_PROFILE)
        self.assertEqual(len(result), 2)
        exercise_chips = set(QUESTION_BANK["exercise"]["general"])
        for chip in result:
            self.assertIn(chip, exercise_chips, f"Expected exercise chip, got: '{chip}'")

    def test_hydration_query_bypasses_combination_bank(self) -> None:
        """Hydration query for multi-condition user must return hydration chips."""
        from app.routers.question_banks import QUESTION_BANK
        result = _run("How much water should I drink daily?", self._MULTI_CONDITION_PROFILE)
        self.assertEqual(len(result), 2)
        hydration_chips = set(QUESTION_BANK["hydration"]["general"])
        for chip in result:
            self.assertIn(chip, hydration_chips, f"Expected hydration chip, got: '{chip}'")

    def test_food_query_still_fires_combination_bank(self) -> None:
        """A food query for multi-condition user must still use the combination bank."""
        result = _run("What should I eat?", self._MULTI_CONDITION_PROFILE)
        self.assertEqual(len(result), 2)
        combo = self._combo_chips()
        for chip in result:
            self.assertIn(chip, combo, f"Expected combo chip for food query, got: '{chip}'")

    def test_followup_query_bypasses_combination_bank(self) -> None:
        """Vague follow-up ('tell me more') must not return combination bank chips."""
        result = _run("tell me more about that", self._MULTI_CONDITION_PROFILE)
        self.assertEqual(len(result), 2)
        combo = self._combo_chips()
        for chip in result:
            self.assertNotIn(chip, combo, f"Combo chip appeared on follow-up: '{chip}'")


class TestStarterSubBucketUniqueness(unittest.TestCase):
    """generate_starter_questions must not return two questions from the same lifestyle topic."""

    def _lifestyle_topic(self, question: str) -> str:
        q = question.lower()
        if any(k in q for k in {"active", "exercise"}):
            return "exercise"
        if "sleep" in q:
            return "sleep"
        if any(k in q for k in {"water", "drink", "hydrat"}):
            return "hydration"
        return "food"

    def _run_many(self, profile: dict, n: int = 30) -> list[list[str]]:
        from app.routers.question_banks import generate_starter_questions
        conditions = profile.get("medicalConditions", [])
        return [generate_starter_questions(conditions, profile) for _ in range(n)]

    def test_no_duplicate_lifestyle_topics_diabetes_plate(self) -> None:
        profile = {"medicalConditions": ["diabetes"], "myPlanType": "Diabetes Plate"}
        for result in self._run_many(profile):
            topics = [self._lifestyle_topic(q) for q in result if self._lifestyle_topic(q) != "food"]
            self.assertEqual(len(topics), len(set(topics)),
                             f"Duplicate lifestyle topic in: {result}")

    def test_no_duplicate_lifestyle_topics_dash(self) -> None:
        profile = {"medicalConditions": ["hypertension"], "myPlanType": "DASH"}
        for result in self._run_many(profile):
            topics = [self._lifestyle_topic(q) for q in result if self._lifestyle_topic(q) != "food"]
            self.assertEqual(len(topics), len(set(topics)),
                             f"Duplicate lifestyle topic in: {result}")

    def test_returns_exactly_five_starters(self) -> None:
        profile = {"medicalConditions": ["diabetes", "hypertension"], "myPlanType": "Diabetes Plate"}
        from app.routers.question_banks import generate_starter_questions
        for _ in range(20):
            result = generate_starter_questions(["diabetes", "hypertension"], profile)
            self.assertEqual(len(result), 5, f"Expected 5 starters, got {len(result)}: {result}")


if __name__ == "__main__":
    unittest.main()
