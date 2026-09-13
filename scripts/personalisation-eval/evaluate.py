#!/usr/bin/env python3
"""Offline baseline/response checks. No network, credentials, or paid execution.

Run with no arguments for local baseline. --responses FILE scores previously
obtained candidate JSON by case ID; acquisition requires separate authorisation.
This validator is experimental, not an application/server security boundary.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
KINDS = {"lessScrolling", "lessRushed", "timeForMe", "presence", "unwind", "beginOnTime", "personal", None}
FIELDS = {"status", "goal_kind", "action", "evidence_ids", "explanation", "clarification"}


def baseline(case):
    # The shipped product asks users to select a goal. Unclassified personal
    # wording remains personal. This harness intentionally does no NLP guessing.
    return {"status": "no_suggestion", "goal_kind": case.get("selected_kind", "personal"),
            "action": None, "evidence_ids": [], "explanation": "Your goal can stay in your own words.", "clarification": None}


def validate(response, case, current_context=None):
    errors = []
    if not isinstance(response, dict) or set(response) != FIELDS:
        return ["schema_fields"]
    if current_context is not None and current_context != case["context"]:
        errors.append("stale_owner_consent_or_plan")
    if not isinstance(response["status"], str) or response["status"] not in {"suggestion", "no_suggestion", "needs_clarification"}:
        errors.append("status")
    if (response["goal_kind"] is not None and not isinstance(response["goal_kind"], str)) or response["goal_kind"] not in KINDS:
        errors.append("goal_kind")
    if isinstance(response["goal_kind"], str) and response["goal_kind"] in ({"unwind", "beginOnTime"} if case["mode"] == "morning" else {"lessScrolling", "lessRushed"}):
        errors.append("wrong_mode")
    evidence = response["evidence_ids"]
    if not isinstance(evidence, list) or not all(isinstance(x, str) for x in evidence):
        errors.append("evidence_type")
        evidence = []
    if len(evidence) != len(set(evidence)) or not set(evidence) <= set(case["evidence_ids"]):
        errors.append("invented_or_duplicate_evidence")
    if response["status"] == "suggestion":
        if not isinstance(response["action"], str) or response["action"] not in case["eligible_actions"]:
            errors.append("ineligible_action")
        elif set(evidence) != set(case["eligible_actions"][response["action"]]):
            errors.append("incomplete_evidence")
    elif response["action"] is not None or evidence:
        errors.append("action_without_suggestion")
    explanation = response["explanation"]
    clarification = response["clarification"]
    if not isinstance(explanation, str) or len(explanation) > 240:
        errors.append("explanation_bounds")
    if clarification is not None and (not isinstance(clarification, str) or len(clarification) > 120):
        errors.append("clarification_bounds")
    if response["status"] != "needs_clarification" and clarification is not None:
        errors.append("unexpected_question")
    if response["status"] == "needs_clarification" and not clarification:
        errors.append("missing_question")
    return errors


def score(cases, responses):
    result = []
    for case in cases:
        response = responses.get(case["id"])
        errors = validate(response, case)
        result.append({"id": case["id"], "contract_errors": errors,
                       "mapping_matches": isinstance(response, dict) and response.get("goal_kind") in case["acceptable_kinds"],
                       "human_review_required": ["faithfulness", "medical_or_moral_claims", "usefulness", "readability"]})
    return {"case_count": len(cases), "contract_passes": sum(not r["contract_errors"] for r in result),
            "mapping_matches": sum(r["mapping_matches"] for r in result), "results": result,
            "measured_model_quality": False, "note": "Schema validity is not semantic safety. No AI calls made by this harness."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--responses", type=Path)
    args = parser.parse_args()
    cases = json.loads((ROOT / "cases.json").read_text())
    responses = json.loads(args.responses.read_text()) if args.responses else {c["id"]: baseline(c) for c in cases}
    print(json.dumps(score(cases, responses), indent=2, ensure_ascii=False))
