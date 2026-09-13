import copy
import unittest
from evaluate import baseline, validate

class ResponseContractTests(unittest.TestCase):
    def setUp(self):
        self.case = {"mode": "morning", "context": {"owner": "A", "consent": 1, "plan": "p1"},
                     "eligible_actions": {"simplify": ["e1", "e2"]}, "evidence_ids": ["e1", "e2"]}
        self.good = {"status": "suggestion", "goal_kind": "lessRushed", "action": "simplify",
                     "evidence_ids": ["e1", "e2"], "explanation": "You reported too much to fit in on two days.", "clarification": None}

    def test_valid_bounded_offer_and_local_fallback(self):
        self.assertEqual(validate(self.good, self.case, self.case["context"]), [])
        self.assertEqual(validate(baseline(self.case), self.case), [])

    def test_wrong_actions_ids_modes_and_incomplete_evidence(self):
        for field, value in [("action", "shorten_timer"), ("action", "disable_shield"),
                             ("action", "grant_reward"), ("evidence_ids", ["e999"]),
                             ("evidence_ids", ["e1"]), ("evidence_ids", ["e1", "e1"]),
                             ("goal_kind", "unwind"), ("status", "refused")]:
            with self.subTest(field=field, value=value):
                response = copy.deepcopy(self.good); response[field] = value
                self.assertTrue(validate(response, self.case))

    def test_account_consent_and_revision_fences(self):
        for key, value in [("owner", "B"), ("consent", 2), ("plan", "p2")]:
            context = dict(self.case["context"]); context[key] = value
            self.assertIn("stale_owner_consent_or_plan", validate(self.good, self.case, context))

    def test_unavailable_refused_truncated_and_unexpected_fields(self):
        for response in [None, {}, "truncated", {"refusal": "no"}, dict(self.good, duration=5)]:
            self.assertTrue(validate(response, self.case))

    def test_text_limits_and_unrequested_clarification(self):
        for field, value in [("explanation", "a" * 241), ("clarification", "why?"), ("evidence_ids", "e1")]:
            response = copy.deepcopy(self.good); response[field] = value
            self.assertTrue(validate(response, self.case))

    def test_no_eligible_action_means_no_offer(self):
        self.case["eligible_actions"] = {}
        self.assertIn("ineligible_action", validate(self.good, self.case))

    def test_wrong_nested_types_are_rejected_without_crashing(self):
        for field in ["status", "goal_kind", "action", "evidence_ids", "explanation", "clarification"]:
            response = dict(self.good); response[field] = {"untrusted": "value"}
            self.assertTrue(validate(response, self.case))

    def test_schema_is_not_a_semantic_safety_claim(self):
        response = dict(self.good, explanation="This will cure insomnia.")
        self.assertEqual(validate(response, self.case), [])  # must fail human critical review

if __name__ == "__main__":
    unittest.main()
