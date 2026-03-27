#!/usr/bin/env python3
"""Run MCP contract regression checks for fix-loop lifecycle."""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

CORE_DIR = Path(__file__).resolve().parent
MCP_DIR = CORE_DIR.parent / "mcp"
import sys

if str(MCP_DIR) not in sys.path:
    sys.path.insert(0, str(MCP_DIR))

from server import AppError, GameTestMcpServer  # noqa: E402


def _utc_now_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _record_case(name: str, ok: bool, details: dict[str, Any]) -> dict[str, Any]:
    return {
        "name": name,
        "ok": ok,
        "details": details,
    }


def run_contract_suite(project_root: Path, godot_bin: str, timeout_sec: int) -> tuple[dict[str, Any], int]:
    server = GameTestMcpServer(default_project_root=project_root)
    flow_file = project_root / "flows" / "internal" / "contract_force_fail_invalid_scene.json"
    cases: list[dict[str, Any]] = []

    # Case 1: waiting_approval contract.
    waiting_payload = server.run_game_flow(
        {
            "flow_file": str(flow_file),
            "project_root": str(project_root),
            "godot_bin": godot_bin,
            "timeout_sec": timeout_sec,
            "bounded_auto_fix": 2,
            "approve_fix_plan": False,
        }
    )
    run_id_wait = str(waiting_payload.get("run_id", ""))
    waiting_ok = (
        waiting_payload.get("status") == "waiting_approval"
        and bool(waiting_payload.get("approval_required", False))
        and int(waiting_payload.get("fix_loop_round", -1)) == 0
    )
    cases.append(
        _record_case(
            "waiting_approval_contract",
            waiting_ok,
            {
                "run_id": run_id_wait,
                "status": waiting_payload.get("status"),
                "current_step": waiting_payload.get("current_step"),
                "approval_required": waiting_payload.get("approval_required"),
            },
        )
    )

    status_payload = server.get_test_run_status({"run_id": run_id_wait, "project_root": str(project_root)})
    status_ok = (
        status_payload.get("status") == "waiting_approval"
        and status_payload.get("current_step") == "waiting_approval"
        and bool(status_payload.get("approval_required", False))
    )
    cases.append(
        _record_case(
            "get_status_waiting_approval",
            status_ok,
            {
                "run_id": run_id_wait,
                "status": status_payload.get("status"),
                "current_step": status_payload.get("current_step"),
                "approval_required": status_payload.get("approval_required"),
            },
        )
    )

    # Case 2: resume -> exhausted with stop reason.
    resume_payload = server.resume_fix_loop({"run_id": run_id_wait, "project_root": str(project_root)})
    fix_loop = resume_payload.get("fix_loop", {})
    stop_reason = str(fix_loop.get("stop_reason", "")) if isinstance(fix_loop, dict) else ""
    rounds_executed = int(fix_loop.get("rounds_executed", -1)) if isinstance(fix_loop, dict) else -1
    resume_ok = (
        resume_payload.get("status") == "exhausted"
        and resume_payload.get("current_step") == "exhausted"
        and rounds_executed == 2
        and stop_reason == "same_failure_without_improvement_for_2_rounds"
    )
    cases.append(
        _record_case(
            "resume_exhausted_stop_reason",
            resume_ok,
            {
                "run_id": run_id_wait,
                "status": resume_payload.get("status"),
                "current_step": resume_payload.get("current_step"),
                "rounds_executed": rounds_executed,
                "stop_reason": stop_reason,
            },
        )
    )

    # Case 3: cancel flow while waiting approval.
    cancel_seed_payload = server.run_game_flow(
        {
            "flow_file": str(flow_file),
            "project_root": str(project_root),
            "godot_bin": godot_bin,
            "timeout_sec": timeout_sec,
            "bounded_auto_fix": 2,
            "approve_fix_plan": False,
        }
    )
    run_id_cancel = str(cancel_seed_payload.get("run_id", ""))
    cancel_payload = server.cancel_test_run({"run_id": run_id_cancel, "project_root": str(project_root)})
    cancel_ok = (
        cancel_payload.get("status") == "cancelled"
        and cancel_payload.get("current_step") == "cancelled"
        and not bool(cancel_payload.get("approval_required", True))
    )
    cases.append(
        _record_case(
            "cancel_waiting_run",
            cancel_ok,
            {
                "run_id": run_id_cancel,
                "status": cancel_payload.get("status"),
                "current_step": cancel_payload.get("current_step"),
                "approval_required": cancel_payload.get("approval_required"),
            },
        )
    )

    resume_after_cancel = server.resume_fix_loop({"run_id": run_id_cancel, "project_root": str(project_root)})
    resume_after_cancel_ok = (
        resume_after_cancel.get("status") == "cancelled"
        and resume_after_cancel.get("current_step") == "cancelled"
    )
    cases.append(
        _record_case(
            "resume_after_cancel_keeps_cancelled",
            resume_after_cancel_ok,
            {
                "run_id": run_id_cancel,
                "status": resume_after_cancel.get("status"),
                "current_step": resume_after_cancel.get("current_step"),
            },
        )
    )

    suite_status = "passed" if all(c["ok"] for c in cases) else "failed"
    suite_id = f"{_utc_now_id()}_contract_regression_suite"
    suite_root = project_root / "artifacts" / "test-suites" / suite_id
    suite_root.mkdir(parents=True, exist_ok=True)

    summary = {
        "suite_id": suite_id,
        "status": suite_status,
        "started_at": _utc_now_iso(),
        "project_root": str(project_root),
        "flow_file": str(flow_file),
        "cases": cases,
    }
    (suite_root / "suite_report.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [
        "# Contract Regression Suite",
        "",
        f"- suite_id: `{suite_id}`",
        f"- status: `{suite_status}`",
        f"- flow_file: `{flow_file}`",
        "",
        "## Cases",
    ]
    for c in cases:
        lines.append(f"- `{c['name']}` -> `{c['ok']}`")
        details = c.get("details", {})
        if isinstance(details, dict):
            for k, v in details.items():
                lines.append(f"  - {k}: `{v}`")
    (suite_root / "suite_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    return summary, (0 if suite_status == "passed" else 1)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run MCP contract regression suite.")
    parser.add_argument("--project-root", required=True, help="Project root path")
    parser.add_argument("--godot-bin", default=os.environ.get("GODOT_BIN", "godot4"), help="Godot executable path")
    parser.add_argument("--timeout-sec", type=int, default=30, help="Timeout for each flow run")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    project_root = Path(args.project_root).resolve()
    try:
        summary, code = run_contract_suite(project_root=project_root, godot_bin=str(args.godot_bin), timeout_sec=int(args.timeout_sec))
        print(json.dumps(summary, ensure_ascii=False))
        return code
    except AppError as exc:
        print(json.dumps({"ok": False, "error": exc.as_dict()}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
