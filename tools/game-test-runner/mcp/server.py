#!/usr/bin/env python3
"""Minimal MCP adapter for game test runner.

Current tools (v0 minimal):
- list_test_scenarios
- run_game_test
- run_game_flow
- get_test_artifacts
- get_test_report
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

CORE_DIR = Path(__file__).resolve().parents[1] / "core"
if str(CORE_DIR) not in sys.path:
    sys.path.insert(0, str(CORE_DIR))

from runner import GameTestRunner, RunRequest  # noqa: E402
from scenario_registry import (  # noqa: E402
    get_default_scenario_by_system,
    get_scenario_by_name,
    list_scenarios,
)
from flow_runner import execute_flow_file  # noqa: E402


class GameTestMcpServer:
    def __init__(self, default_project_root: Path) -> None:
        self.default_project_root = default_project_root.resolve()

    def list_test_scenarios(self, _arguments: dict[str, Any]) -> dict[str, Any]:
        scenarios = list_scenarios()
        for scenario in scenarios:
            if "scene" in scenario:
                scenario["scene"] = _to_posix(scenario["scene"])
        return {"scenarios": scenarios}

    def run_game_test(self, arguments: dict[str, Any]) -> dict[str, Any]:
        system = str(arguments.get("system", "")).strip()
        if not system:
            raise AppError("INVALID_ARGUMENT", "system is required")

        scenario = arguments.get("scenario")
        scenario_name: str
        if scenario:
            scenario_name = str(scenario)
            if not get_scenario_by_name(scenario_name):
                raise AppError("UNKNOWN_SCENARIO", f"unknown scenario: {scenario_name}")
        else:
            default_scenario = get_default_scenario_by_system(system)
            if not default_scenario:
                raise AppError("UNKNOWN_SYSTEM", f"no default scenario for system: {system}")
            scenario_name = default_scenario.name

        environment = arguments.get("environment", {}) or {}
        execution = arguments.get("execution", {}) or {}
        mode = str(environment.get("mode", "vm"))
        if mode not in {"vm", "local", "headless"}:
            raise AppError("INVALID_ARGUMENT", f"unsupported mode: {mode}")
        timeout_sec = int(execution.get("timeoutSec", 300))
        if timeout_sec <= 0:
            raise AppError("INVALID_ARGUMENT", "execution.timeoutSec must be > 0")
        retry = int(execution.get("retry", 0))
        if retry < 0:
            raise AppError("INVALID_ARGUMENT", "execution.retry must be >= 0")

        project_root_raw = arguments.get("project_root", str(self.default_project_root))
        project_root = Path(str(project_root_raw)).resolve()
        if not project_root.exists():
            raise AppError("INVALID_ARGUMENT", f"project_root not found: {project_root}")

        req = RunRequest(
            system=system,
            project_root=project_root,
            scenario=scenario_name,
            profile=str(arguments.get("profile", "smoke")),
            mode=mode,
            timeout_sec=timeout_sec,
            retry=retry,
            clean_save_slots=bool(execution.get("cleanSaveSlots", True)),
            godot_bin=str(arguments.get("godot_bin", "godot4")),
            scene=arguments.get("scene"),
            extra_args=list(arguments.get("extra_args", [])),
            dry_run=bool(arguments.get("dry_run", False)),
            enable_test_driver=bool(arguments.get("enable_test_driver", False)),
            flow_steps=list(arguments.get("flow_steps", [])),
            flow_step_timeout_sec=int(arguments.get("flow_step_timeout_sec", 15)),
        )

        runner = GameTestRunner(project_root=project_root)
        result = runner.run(req)
        return {
            "run_id": result.run_id,
            "status": result.status,
            "started_at": result.started_at,
            "finished_at": result.finished_at,
            "artifact_root": _to_posix(result.artifact_root),
            "exit_code": result.exit_code,
            "command": [_to_posix(c) for c in result.command],
        }

    def _resolve_run_root(self, run_id: str, arguments: dict[str, Any]) -> Path:
        run_id = run_id.strip()
        if not run_id:
            raise AppError("INVALID_ARGUMENT", "run_id is required")
        artifact_base_raw = arguments.get("artifact_base")
        artifact_base = (
            Path(str(artifact_base_raw)).resolve()
            if artifact_base_raw
            else self.default_project_root / "artifacts" / "test-runs"
        )
        run_root = artifact_base / run_id
        if not run_root.exists():
            raise AppError("NOT_FOUND", f"run artifacts not found: {run_root}")
        return run_root

    def get_test_artifacts(self, arguments: dict[str, Any]) -> dict[str, Any]:
        run_id = str(arguments.get("run_id", "")).strip()
        run_root = self._resolve_run_root(run_id, arguments)
        logs = sorted([p.relative_to(run_root).as_posix() for p in (run_root / "logs").glob("*") if p.is_file()])
        screenshots = sorted(
            [p.relative_to(run_root).as_posix() for p in (run_root / "screenshots").glob("*") if p.is_file()]
        )
        save_snapshots = sorted(
            [p.relative_to(run_root).as_posix() for p in (run_root / "save_snapshots").glob("*") if p.is_file()]
        )
        report_json = (run_root / "report.json").relative_to(run_root).as_posix() if (run_root / "report.json").exists() else ""
        report_md = (run_root / "report.md").relative_to(run_root).as_posix() if (run_root / "report.md").exists() else ""
        return {
            "run_id": run_id,
            "artifact_root": _to_posix(run_root),
            "logs": logs,
            "screenshots": screenshots,
            "save_snapshots": save_snapshots,
            "report_json": report_json,
            "report_md": report_md,
        }

    def get_test_report(self, arguments: dict[str, Any]) -> dict[str, Any]:
        run_id = str(arguments.get("run_id", "")).strip()
        fmt = str(arguments.get("format", "json")).strip().lower()
        if fmt not in {"json", "md"}:
            raise AppError("INVALID_ARGUMENT", "format must be json or md")
        run_root = self._resolve_run_root(run_id, arguments)
        if fmt == "json":
            report_path = run_root / "report.json"
            if not report_path.exists():
                raise AppError("NOT_FOUND", f"missing report file: {report_path}")
            payload = json.loads(report_path.read_text(encoding="utf-8"))
            return {"run_id": run_id, "format": "json", "report": payload}
        report_path = run_root / "report.md"
        if not report_path.exists():
            raise AppError("NOT_FOUND", f"missing report file: {report_path}")
        return {"run_id": run_id, "format": "md", "report": report_path.read_text(encoding="utf-8")}

    def run_game_flow(self, arguments: dict[str, Any]) -> dict[str, Any]:
        flow_file_raw = str(arguments.get("flow_file", "")).strip()
        if not flow_file_raw:
            raise AppError("INVALID_ARGUMENT", "flow_file is required")
        flow_file = Path(flow_file_raw).resolve()
        if not flow_file.exists():
            raise AppError("NOT_FOUND", f"flow file not found: {flow_file}")
        project_root_raw = arguments.get("project_root", str(self.default_project_root))
        project_root = Path(str(project_root_raw)).resolve()
        timeout_sec = int(arguments.get("timeout_sec", 300))
        dry_run = bool(arguments.get("dry_run", False))
        driver_ready_timeout_sec = (
            int(arguments["driver_ready_timeout_sec"]) if arguments.get("driver_ready_timeout_sec") is not None else None
        )
        driver_no_activity_timeout_sec = (
            int(arguments["driver_no_activity_timeout_sec"])
            if arguments.get("driver_no_activity_timeout_sec") is not None
            else None
        )
        godot_bin = str(arguments.get("godot_bin", "godot4"))

        payload, code = execute_flow_file(
            flow_file=flow_file,
            project_root=project_root,
            godot_bin=godot_bin,
            timeout_sec=timeout_sec,
            dry_run=dry_run,
            driver_ready_timeout_sec=driver_ready_timeout_sec,
            driver_no_activity_timeout_sec=driver_no_activity_timeout_sec,
        )
        payload["exit_code"] = code
        initial_report = _load_report(Path(payload["artifact_root"]))
        payload["primary_failure"] = _primary_failure_summary(initial_report)
        payload["fix_loop"] = {
            "enabled": False,
            "max_rounds": 0,
            "rounds_executed": 0,
            "approval_required": False,
            "status": "not_enabled",
            "rounds": [],
        }

        bounded_auto_fix = int(arguments.get("bounded_auto_fix", arguments.get("bounded_auto_fix_max_rounds", 0)))
        if bounded_auto_fix <= 0:
            return payload
        bounded_auto_fix = min(3, bounded_auto_fix)
        approve_fix = bool(arguments.get("approve_fix_plan", False))
        fix_rounds: list[dict[str, Any]] = []
        fix_loop = {
            "enabled": True,
            "max_rounds": bounded_auto_fix,
            "rounds_executed": 0,
            "approval_required": False,
            "status": "running",
            "rounds": fix_rounds,
        }

        if code == 0:
            fix_loop["status"] = "not_needed"
            payload["fix_loop"] = fix_loop
            return payload

        initial_reason = _first_failure_reason(initial_report)
        fix_loop["rounds"].append(
            {
                "round": 0,
                "run_id": payload.get("run_id", ""),
                "status": payload.get("status", "failed"),
                "reason": initial_reason,
                "primary_failure": _primary_failure_summary(initial_report),
            }
        )

        if not approve_fix:
            fix_loop["approval_required"] = True
            fix_loop["status"] = "waiting_approval"
            payload["fix_loop"] = fix_loop
            payload["approval_required"] = True
            payload["proposed_fix_plan"] = {
                "summary": "Retry flow with bounded auto-fix rounds",
                "max_rounds": bounded_auto_fix,
                "first_failure_reason": initial_reason,
            }
            return payload

        current_payload = payload
        current_code = code
        for round_idx in range(1, bounded_auto_fix + 1):
            retry_payload, retry_code = execute_flow_file(
                flow_file=flow_file,
                project_root=project_root,
                godot_bin=godot_bin,
                timeout_sec=timeout_sec,
                dry_run=dry_run,
                driver_ready_timeout_sec=driver_ready_timeout_sec,
                driver_no_activity_timeout_sec=driver_no_activity_timeout_sec,
            )
            retry_payload["exit_code"] = retry_code
            retry_report = _load_report(Path(retry_payload["artifact_root"]))
            retry_reason = _first_failure_reason(retry_report)
            retry_payload["primary_failure"] = _primary_failure_summary(retry_report)
            fix_rounds.append(
                {
                    "round": round_idx,
                    "run_id": retry_payload.get("run_id", ""),
                    "status": retry_payload.get("status", "failed"),
                    "reason": retry_reason,
                    "primary_failure": _primary_failure_summary(retry_report),
                }
            )
            fix_loop["rounds_executed"] = round_idx
            current_payload = retry_payload
            current_code = retry_code
            if retry_code == 0:
                fix_loop["status"] = "resolved"
                break
        else:
            fix_loop["status"] = "exhausted"

        current_payload["fix_loop"] = fix_loop
        current_payload["exit_code"] = current_code
        current_payload["approval_required"] = False
        return current_payload

    def invoke(self, tool_name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        if tool_name == "list_test_scenarios":
            return self.list_test_scenarios(arguments)
        if tool_name == "run_game_test":
            return self.run_game_test(arguments)
        if tool_name == "get_test_artifacts":
            return self.get_test_artifacts(arguments)
        if tool_name == "get_test_report":
            return self.get_test_report(arguments)
        if tool_name == "run_game_flow":
            return self.run_game_flow(arguments)
        raise AppError("UNSUPPORTED_TOOL", f"unsupported tool: {tool_name}")


@dataclass
class AppError(Exception):
    code: str
    message: str
    details: dict[str, Any] | None = None

    def as_dict(self) -> dict[str, Any]:
        out = {"code": self.code, "message": self.message}
        if self.details:
            out["details"] = self.details
        return out


def _load_report(run_root: Path) -> dict[str, Any]:
    report_path = run_root / "report.json"
    if not report_path.exists():
        return {}
    try:
        return json.loads(report_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def _first_failure_reason(report_payload: dict[str, Any]) -> str:
    failures = report_payload.get("failures", [])
    if not isinstance(failures, list) or not failures:
        return ""
    first = failures[0] if isinstance(failures[0], dict) else {}
    reason = str(first.get("actual", "")).strip()
    category = str(first.get("category", "")).strip()
    if reason and category:
        return f"{category}: {reason}"
    return reason or category


def _primary_failure_summary(report_payload: dict[str, Any]) -> dict[str, Any]:
    failures = report_payload.get("failures", [])
    if not isinstance(failures, list) or not failures:
        return {}
    first = failures[0] if isinstance(failures[0], dict) else {}
    return {
        "step_id": str(first.get("stepId", "")),
        "category": str(first.get("category", "")),
        "expected": str(first.get("expected", "")),
        "actual": str(first.get("actual", "")),
        "artifacts": list(first.get("artifacts", []))
        if isinstance(first.get("artifacts", []), list)
        else [],
    }


def _to_posix(value: str | Path) -> str:
    return str(value).replace("\\", "/")


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Minimal MCP adapter for game test runner.")
    parser.add_argument("--tool", required=True, help="Tool name")
    parser.add_argument("--args", default="{}", help="JSON string arguments")
    parser.add_argument("--project-root", default=None, help="Default project root")
    parser.add_argument("--system", default=None, help="Shortcut for run_game_test.system")
    parser.add_argument("--scenario", default=None, help="Shortcut for run_game_test.scenario")
    parser.add_argument("--dry-run", action="store_true", help="Shortcut for run_game_test.dry_run")
    parser.add_argument("--run-id", default=None, help="Shortcut for report/artifact query run_id")
    parser.add_argument("--format", default=None, help="Shortcut for get_test_report format")
    parser.add_argument("--flow-file", default=None, help="Shortcut for run_game_flow flow_file")
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    default_root = (
        Path(args.project_root).resolve()
        if args.project_root
        else Path(__file__).resolve().parents[3]
    )
    server = GameTestMcpServer(default_project_root=default_root)
    try:
        tool_args = json.loads(args.args)
        if not isinstance(tool_args, dict):
            raise AppError("INVALID_ARGUMENT", "args must be a JSON object")
        if args.tool == "run_game_test":
            if args.system is not None:
                tool_args["system"] = args.system
            if args.scenario is not None:
                tool_args["scenario"] = args.scenario
            if args.dry_run:
                tool_args["dry_run"] = True
        if args.tool in {"get_test_artifacts", "get_test_report"}:
            if args.run_id is not None:
                tool_args["run_id"] = args.run_id
        if args.tool == "run_game_flow" and args.flow_file is not None:
            tool_args["flow_file"] = args.flow_file
            if args.dry_run:
                tool_args["dry_run"] = True
        if args.tool == "get_test_report" and args.format is not None:
            tool_args["format"] = args.format
        result = server.invoke(args.tool, tool_args)
        print(json.dumps({"ok": True, "result": result}, ensure_ascii=False))
        return 0
    except AppError as exc:
        print(json.dumps({"ok": False, "error": exc.as_dict()}, ensure_ascii=False))
        return 1
    except Exception as exc:  # pylint: disable=broad-except
        print(
            json.dumps(
                {"ok": False, "error": {"code": "INTERNAL_ERROR", "message": str(exc)}},
                ensure_ascii=False,
            )
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
