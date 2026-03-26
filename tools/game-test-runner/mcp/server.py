#!/usr/bin/env python3
"""Minimal MCP adapter for game test runner.

Current tools (v0 minimal):
- list_test_scenarios
- run_game_test
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

    def invoke(self, tool_name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        if tool_name == "list_test_scenarios":
            return self.list_test_scenarios(arguments)
        if tool_name == "run_game_test":
            return self.run_game_test(arguments)
        if tool_name == "get_test_artifacts":
            return self.get_test_artifacts(arguments)
        if tool_name == "get_test_report":
            return self.get_test_report(arguments)
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
