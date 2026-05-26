import sys
import unittest
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.services.rag_service import _QueryClass, classify_query


class TestQueryClassificationScope(unittest.TestCase):
    def test_supported_condition_diabetes_stays_diet_scope(self) -> None:
        result = classify_query("What foods are best for my diabetes?")
        self.assertEqual(result, _QueryClass.DIET)

    def test_supported_condition_hypertension_stays_diet_scope(self) -> None:
        result = classify_query("Can you suggest low-sodium meals for hypertension?")
        self.assertEqual(result, _QueryClass.DIET)

    def test_out_of_scope_condition_cancer_routes_to_medical(self) -> None:
        result = classify_query("What foods should I eat during cancer treatment?")
        self.assertEqual(result, _QueryClass.MEDICAL)

    def test_out_of_scope_condition_tumor_routes_to_medical(self) -> None:
        result = classify_query("I have a brain tumor. What diet should I follow?")
        self.assertEqual(result, _QueryClass.MEDICAL)

    def test_out_of_scope_condition_with_supported_terms_is_still_medical(self) -> None:
        result = classify_query(
            "I have cancer and high blood pressure. What should I eat?"
        )
        self.assertEqual(result, _QueryClass.MEDICAL)


if __name__ == "__main__":
    unittest.main()
