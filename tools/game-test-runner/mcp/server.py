#!/usr/bin/env python3
"""Minimal MCP adapter for game test runner.

Current tools (v0 minimal):
- list_test_scenarios
- run_game_test
- run_game_flow
- check_test_runner_environment
- get_test_run_status
- cancel_test_run
- resume_fix_loop
- get_test_artifacts
- get_test_report
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

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

        requested_godot_bin = str(arguments.get("godot_bin", "godot4"))
        resolved_godot_bin, resolution_meta = _resolve_godot_bin(
            requested=requested_godot_bin,
            strict=bool(arguments.get("strict_godot_bin", False)),
            allow_unresolved=bool(arguments.get("dry_run", False)),
        )

        req = RunRequest(
            system=system,
            project_root=project_root,
            scenario=scenario_name,
            profile=str(arguments.get("profile", "smoke")),
            mode=mode,
            timeout_sec=timeout_sec,
            retry=retry,
            clean_save_slots=bool(execution.get("cleanSaveSlots", True)),
            godot_bin=resolved_godot_bin,
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
            "godot_bin_requested": requested_godot_bin,
            "godot_bin_resolved": resolved_godot_bin,
            "godot_bin_resolution": resolution_meta,
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

    @staticmethod
    def _status_file(run_root: Path) -> Path:
        return run_root / "fix_loop_state.json"

    def _save_fix_loop_state(self, run_root: Path, state: dict[str, Any]) -> None:
        self._status_file(run_root).write_text(
            json.dumps(state, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def _load_fix_loop_state(self, run_root: Path) -> dict[str, Any]:
        state_path = self._status_file(run_root)
        if not state_path.exists():
            return {}
        try:
            data = json.loads(state_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
        if not isinstance(data, dict):
            return {}
        return data

    def _load_status_by_run_id(self, run_id: str, arguments: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
        run_root = self._resolve_run_root(run_id, arguments)
        state = self._load_fix_loop_state(run_root)
        if state:
            return run_root, state
        report = _load_report(run_root)
        primary_failure = _primary_failure_summary(report)
        failures = report.get("failures", []) if isinstance(report.get("failures", []), list) else []
        has_failures = len(failures) > 0
        fallback = {
            "version": 2,
            "run_id": run_id,
            "artifact_root": _to_posix(run_root),
            "status": "exhausted" if has_failures else "resolved",
            "current_step": "completed",
            "fix_loop_round": 0,
            "approval_required": False,
            "fix_loop": {
                "enabled": False,
                "max_rounds": 0,
                "rounds_executed": 0,
                "approval_required": False,
                "status": "not_enabled",
                "rounds": [
                    {
                        "round": 0,
                        "run_id": run_id,
                        "status": "failed" if has_failures else "passed",
                        "reason": _first_failure_reason(report),
                        "primary_failure": primary_failure,
                    }
                ],
            },
        }
        return run_root, fallback

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
        junit_xml = (run_root / "junit.xml").relative_to(run_root).as_posix() if (run_root / "junit.xml").exists() else ""
        flow_report_json = (
            (run_root / "flow_report.json").relative_to(run_root).as_posix() if (run_root / "flow_report.json").exists() else ""
        )
        driver_flow_json = (
            (run_root / "logs" / "driver_flow.json").relative_to(run_root).as_posix()
            if (run_root / "logs" / "driver_flow.json").exists()
            else ""
        )
        failure_summary_json = (
            (run_root / "failure_summary.json").relative_to(run_root).as_posix()
            if (run_root / "failure_summary.json").exists()
            else ""
        )
        return {
            "run_id": run_id,
            "artifact_root": _to_posix(run_root),
            "logs": logs,
            "screenshots": screenshots,
            "save_snapshots": save_snapshots,
            "report_json": report_json,
            "report_md": report_md,
            "junit_xml": junit_xml,
            "flow_report_json": flow_report_json,
            "driver_flow_json": driver_flow_json,
            "failure_summary_json": failure_summary_json,
            "key_files": [
                path
                for path in [report_json, report_md, junit_xml, flow_report_json, driver_flow_json, failure_summary_json]
                if path
            ],
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

    def check_test_runner_environment(self, arguments: dict[str, Any]) -> dict[str, Any]:
        requested_godot_bin = str(arguments.get("godot_bin", "godot4"))
        strict = bool(arguments.get("strict_godot_bin", True))
        checks: list[dict[str, Any]] = []
        recommendations: list[str] = []
        ok = True

        try:
            resolved_godot_bin, resolution = _resolve_godot_bin(
                requested=requested_godot_bin,
                strict=strict,
                allow_unresolved=False,
            )
            checks.append(
                {
                    "id": "godot_bin",
                    "status": "passed",
                    "message": "Godot executable resolved",
                    "resolved": resolved_godot_bin,
                    "resolution": resolution,
                }
            )
        except AppError as exc:
            ok = False
            checks.append(
                {
                    "id": "godot_bin",
                    "status": "failed",
                    "message": exc.message,
                    "details": exc.details or {},
                }
            )
            recommendations.append(
                "Set GODOT_BIN to a valid Godot executable path, then open a new shell session."
            )
            recommendations.append(
                "PowerShell: setx GODOT_BIN \"D:\\GODOT\\Godot_v4.6.1-stable_win64.exe\\Godot_v4.6.1-stable_win64.exe\""
            )
            resolved_godot_bin = ""
            resolution = {}

        project_root_raw = arguments.get("project_root", str(self.default_project_root))
        project_root = Path(str(project_root_raw)).resolve()
        if project_root.exists() and project_root.is_dir():
            checks.append(
                {
                    "id": "project_root",
                    "status": "passed",
                    "message": "project_root exists",
                    "path": _to_posix(project_root),
                }
            )
        else:
            ok = False
            checks.append(
                {
                    "id": "project_root",
                    "status": "failed",
                    "message": f"project_root not found: {project_root}",
                    "path": _to_posix(project_root),
                }
            )

        return {
            "ok": ok,
            "godot_bin_requested": requested_godot_bin,
            "godot_bin_resolved": resolved_godot_bin,
            "godot_bin_resolution": resolution,
            "checks": checks,
            "recommendations": recommendations,
            "ci_ready": ok,
        }

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
        requested_godot_bin = str(arguments.get("godot_bin", "godot4"))
        godot_bin, godot_resolution = _resolve_godot_bin(
            requested=requested_godot_bin,
            strict=bool(arguments.get("strict_godot_bin", False)),
            allow_unresolved=dry_run,
        )

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
        payload["flow_status"] = str(payload.get("status", ""))
        payload["godot_bin_requested"] = requested_godot_bin
        payload["godot_bin_resolved"] = godot_bin
        payload["godot_bin_resolution"] = godot_resolution
        initial_report = _load_report(Path(payload["artifact_root"]))
        initial_effective_exit_code, initial_process_exit_code = _report_exit_codes(initial_report)
        payload["effective_exit_code"] = initial_effective_exit_code
        payload["process_exit_code"] = initial_process_exit_code
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
            payload["status"] = "resolved" if code == 0 else "exhausted"
            payload["current_step"] = "completed"
            payload["fix_loop_round"] = 0
            payload["approval_required"] = False
            self._save_fix_loop_state(
                Path(payload["artifact_root"]),
                {
                    "version": 2,
                    "run_id": str(payload.get("run_id", "")),
                    "artifact_root": _to_posix(Path(payload["artifact_root"])),
                    "status": payload["status"],
                    "current_step": payload["current_step"],
                    "fix_loop_round": 0,
                    "approval_required": False,
                    "fix_loop": payload["fix_loop"],
                },
            )
            return _with_status_shape(payload)
        bounded_auto_fix = min(3, bounded_auto_fix)
        approve_fix = bool(arguments.get("approve_fix_plan", False))
        fix_rounds: list[dict[str, Any]] = []
        fix_loop = {
            "enabled": True,
            "max_rounds": bounded_auto_fix,
            "rounds_executed": 0,
            "approval_required": False,
            "status": "analyzing",
            "rounds": fix_rounds,
        }

        if code == 0:
            fix_loop["status"] = "resolved"
            payload["fix_loop"] = fix_loop
            payload["status"] = "resolved"
            payload["current_step"] = "resolved"
            payload["fix_loop_round"] = 0
            payload["approval_required"] = False
            self._save_fix_loop_state(
                Path(payload["artifact_root"]),
                {
                    "version": 2,
                    "run_id": str(payload.get("run_id", "")),
                    "artifact_root": _to_posix(Path(payload["artifact_root"])),
                    "status": "resolved",
                    "current_step": "resolved",
                    "fix_loop_round": 0,
                    "approval_required": False,
                    "fix_loop": fix_loop,
                    "config": {
                        "flow_file": _to_posix(flow_file),
                        "project_root": _to_posix(project_root),
                        "godot_bin": godot_bin,
                        "godot_bin_requested": requested_godot_bin,
                        "godot_bin_resolution": godot_resolution,
                        "timeout_sec": timeout_sec,
                        "dry_run": dry_run,
                        "driver_ready_timeout_sec": driver_ready_timeout_sec,
                        "driver_no_activity_timeout_sec": driver_no_activity_timeout_sec,
                        "bounded_auto_fix": bounded_auto_fix,
                    },
                },
            )
            return _with_status_shape(payload)

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
        fix_loop["rounds_executed"] = 0

        run_root = Path(payload["artifact_root"])
        state: dict[str, Any] = {
            "version": 2,
            "run_id": str(payload.get("run_id", "")),
            "artifact_root": _to_posix(run_root),
            "status": "analyzing",
            "current_step": "analyzing",
            "fix_loop_round": 0,
            "approval_required": False,
            "fix_loop": fix_loop,
            "config": {
                "flow_file": _to_posix(flow_file),
                "project_root": _to_posix(project_root),
                "godot_bin": godot_bin,
                "godot_bin_requested": requested_godot_bin,
                "godot_bin_resolution": godot_resolution,
                "timeout_sec": timeout_sec,
                "dry_run": dry_run,
                "driver_ready_timeout_sec": driver_ready_timeout_sec,
                "driver_no_activity_timeout_sec": driver_no_activity_timeout_sec,
                "bounded_auto_fix": bounded_auto_fix,
            },
            "last_payload": payload,
        }
        self._save_fix_loop_state(run_root, state)

        if not approve_fix:
            fix_loop["approval_required"] = True
            fix_loop["status"] = "waiting_approval"
            payload["fix_loop"] = fix_loop
            payload["status"] = "waiting_approval"
            payload["current_step"] = "waiting_approval"
            payload["fix_loop_round"] = 0
            payload["approval_required"] = True
            payload["proposed_fix_plan"] = {
                "summary": "Retry flow with bounded auto-fix rounds",
                "max_rounds": bounded_auto_fix,
                "first_failure_reason": initial_reason,
            }
            state["status"] = "waiting_approval"
            state["current_step"] = "waiting_approval"
            state["approval_required"] = True
            state["fix_loop_round"] = 0
            state["fix_loop"] = fix_loop
            state["last_payload"] = payload
            self._save_fix_loop_state(run_root, state)
            return _with_status_shape(payload)

        return self._resume_fix_loop_impl(
            run_root=run_root,
            state=state,
            force=False,
        )

    def get_test_run_status(self, arguments: dict[str, Any]) -> dict[str, Any]:
        run_id = str(arguments.get("run_id", "")).strip()
        if not run_id:
            raise AppError("INVALID_ARGUMENT", "run_id is required")
        _, state = self._load_status_by_run_id(run_id, arguments)
        return _with_status_shape(
            {
                "run_id": state.get("run_id", run_id),
                "artifact_root": state.get("artifact_root", ""),
                "status": state.get("status", ""),
                "current_step": state.get("current_step", ""),
                "fix_loop_round": int(state.get("fix_loop_round", 0)),
                "approval_required": bool(state.get("approval_required", False)),
                "fix_loop": state.get("fix_loop", {}),
            }
        )

    def cancel_test_run(self, arguments: dict[str, Any]) -> dict[str, Any]:
        run_id = str(arguments.get("run_id", "")).strip()
        if not run_id:
            raise AppError("INVALID_ARGUMENT", "run_id is required")
        run_root, state = self._load_status_by_run_id(run_id, arguments)
        if state.get("status") in {"resolved", "exhausted"}:
            return _with_status_shape(
                {
                    "run_id": state.get("run_id", run_id),
                    "artifact_root": state.get("artifact_root", ""),
                    "status": state.get("status", ""),
                    "current_step": state.get("current_step", ""),
                    "fix_loop_round": int(state.get("fix_loop_round", 0)),
                    "approval_required": bool(state.get("approval_required", False)),
                    "fix_loop": state.get("fix_loop", {}),
                    "cancelled": False,
                }
            )
        state["status"] = "cancelled"
        state["current_step"] = "cancelled"
        state["approval_required"] = False
        state["cancel_requested"] = True
        fix_loop = state.get("fix_loop", {})
        if isinstance(fix_loop, dict):
            fix_loop["status"] = "cancelled"
            fix_loop["approval_required"] = False
            state["fix_loop"] = fix_loop
        self._save_fix_loop_state(run_root, state)
        return _with_status_shape(
            {
                "run_id": state.get("run_id", run_id),
                "artifact_root": state.get("artifact_root", ""),
                "status": state.get("status", ""),
                "current_step": state.get("current_step", ""),
                "fix_loop_round": int(state.get("fix_loop_round", 0)),
                "approval_required": bool(state.get("approval_required", False)),
                "fix_loop": state.get("fix_loop", {}),
                "cancelled": True,
            }
        )

    def resume_fix_loop(self, arguments: dict[str, Any]) -> dict[str, Any]:
        run_id = str(arguments.get("run_id", "")).strip()
        if not run_id:
            raise AppError("INVALID_ARGUMENT", "run_id is required")
        run_root, state = self._load_status_by_run_id(run_id, arguments)
        force = bool(arguments.get("force", False))
        return self._resume_fix_loop_impl(run_root=run_root, state=state, force=force)

    def _resume_fix_loop_impl(self, run_root: Path, state: dict[str, Any], force: bool) -> dict[str, Any]:
        status = str(state.get("status", ""))
        if status in {"resolved", "exhausted", "cancelled"}:
            return _with_status_shape(
                {
                    "run_id": state.get("run_id", ""),
                    "artifact_root": state.get("artifact_root", ""),
                    "status": status,
                    "current_step": state.get("current_step", ""),
                    "fix_loop_round": int(state.get("fix_loop_round", 0)),
                    "approval_required": bool(state.get("approval_required", False)),
                    "fix_loop": state.get("fix_loop", {}),
                    "last_payload": state.get("last_payload", {}),
                }
            )
        if status != "waiting_approval" and not force:
            raise AppError(
                "INVALID_STATE",
                "resume_fix_loop expects waiting_approval status; set force=true to resume anyway",
            )

        config = state.get("config", {})
        if not isinstance(config, dict):
            raise AppError("INVALID_STATE", "missing flow run config")
        flow_file = Path(str(config.get("flow_file", ""))).resolve()
        project_root = Path(str(config.get("project_root", ""))).resolve()
        if not flow_file.exists():
            raise AppError("NOT_FOUND", f"flow file not found: {flow_file}")
        bounded_auto_fix = int(config.get("bounded_auto_fix", 0))
        if bounded_auto_fix <= 0:
            raise AppError("INVALID_STATE", "bounded_auto_fix is disabled for this run")

        fix_loop = state.get("fix_loop", {})
        if not isinstance(fix_loop, dict):
            fix_loop = {}
        rounds = fix_loop.get("rounds", [])
        if not isinstance(rounds, list):
            rounds = []
        executed = int(fix_loop.get("rounds_executed", 0))
        start_round = max(1, executed + 1)
        max_rounds = int(fix_loop.get("max_rounds", bounded_auto_fix))

        state["status"] = "rerun"
        state["current_step"] = "rerun"
        state["approval_required"] = False
        state["fix_loop"] = {
            "enabled": True,
            "max_rounds": max_rounds,
            "rounds_executed": executed,
            "approval_required": False,
            "status": "rerun",
            "rounds": rounds,
        }
        self._save_fix_loop_state(run_root, state)

        current_payload = state.get("last_payload", {})
        if not isinstance(current_payload, dict):
            current_payload = {}
        current_code = int(current_payload.get("exit_code", 1))
        previous_round_signature: Optional[tuple[str, str]] = None
        if rounds:
            last_pf = rounds[-1].get("primary_failure", {}) if isinstance(rounds[-1], dict) else {}
            if isinstance(last_pf, dict):
                previous_round_signature = (
                    str(last_pf.get("category", "")).strip(),
                    str(last_pf.get("actual", "")).strip(),
                )

        for round_idx in range(start_round, max_rounds + 1):
            latest_state = self._load_fix_loop_state(run_root)
            if str(latest_state.get("status", "")) == "cancelled":
                return _with_status_shape(
                    {
                        "run_id": latest_state.get("run_id", ""),
                        "artifact_root": latest_state.get("artifact_root", ""),
                        "status": "cancelled",
                        "current_step": "cancelled",
                        "fix_loop_round": int(latest_state.get("fix_loop_round", round_idx - 1)),
                        "approval_required": False,
                        "fix_loop": latest_state.get("fix_loop", {}),
                    }
                )

            retry_payload, retry_code = execute_flow_file(
                flow_file=flow_file,
                project_root=project_root,
                godot_bin=str(config.get("godot_bin", "godot4")),
                timeout_sec=int(config.get("timeout_sec", 300)),
                dry_run=bool(config.get("dry_run", False)),
                driver_ready_timeout_sec=(
                    int(config["driver_ready_timeout_sec"]) if config.get("driver_ready_timeout_sec") is not None else None
                ),
                driver_no_activity_timeout_sec=(
                    int(config["driver_no_activity_timeout_sec"])
                    if config.get("driver_no_activity_timeout_sec") is not None
                    else None
                ),
            )
            retry_payload["exit_code"] = retry_code
            retry_payload["flow_status"] = str(retry_payload.get("status", ""))
            retry_payload["godot_bin_requested"] = str(config.get("godot_bin_requested", config.get("godot_bin", "")))
            retry_payload["godot_bin_resolved"] = str(config.get("godot_bin", ""))
            retry_payload["godot_bin_resolution"] = config.get("godot_bin_resolution", {})
            retry_report = _load_report(Path(retry_payload["artifact_root"]))
            retry_effective_exit_code, retry_process_exit_code = _report_exit_codes(retry_report)
            retry_payload["effective_exit_code"] = retry_effective_exit_code
            retry_payload["process_exit_code"] = retry_process_exit_code
            retry_reason = _first_failure_reason(retry_report)
            retry_primary_failure = _primary_failure_summary(retry_report)
            retry_payload["primary_failure"] = retry_primary_failure

            rounds.append(
                {
                    "round": round_idx,
                    "run_id": retry_payload.get("run_id", ""),
                    "status": retry_payload.get("status", "failed"),
                    "reason": retry_reason,
                    "primary_failure": retry_primary_failure,
                }
            )
            current_payload = retry_payload
            current_code = retry_code

            current_signature = (
                str(retry_primary_failure.get("category", "")).strip(),
                str(retry_primary_failure.get("actual", "")).strip(),
            )
            no_improvement = (
                retry_code != 0
                and round_idx >= 2
                and previous_round_signature is not None
                and previous_round_signature == current_signature
                and bool(current_signature[0])
            )
            previous_round_signature = current_signature

            fix_loop = state.get("fix_loop", {})
            if not isinstance(fix_loop, dict):
                fix_loop = {}
            fix_loop["enabled"] = True
            fix_loop["max_rounds"] = max_rounds
            fix_loop["rounds_executed"] = round_idx
            fix_loop["approval_required"] = False
            fix_loop["rounds"] = rounds
            fix_loop["status"] = "rerun"
            state["fix_loop"] = fix_loop
            state["last_payload"] = current_payload
            state["fix_loop_round"] = round_idx
            state["approval_required"] = False
            state["current_step"] = "rerun"
            state["status"] = "rerun"
            if retry_code == 0:
                fix_loop["status"] = "resolved"
                state["status"] = "resolved"
                state["current_step"] = "resolved"
                self._save_fix_loop_state(run_root, state)
                break
            if no_improvement:
                fix_loop["status"] = "exhausted"
                fix_loop["stop_reason"] = "same_failure_without_improvement_for_2_rounds"
                state["status"] = "exhausted"
                state["current_step"] = "exhausted"
                state["stop_reason"] = fix_loop["stop_reason"]
                self._save_fix_loop_state(run_root, state)
                break
            self._save_fix_loop_state(run_root, state)
        else:
            fix_loop = state.get("fix_loop", {})
            if isinstance(fix_loop, dict):
                fix_loop["status"] = "exhausted"
                state["fix_loop"] = fix_loop
            state["status"] = "exhausted"
            state["current_step"] = "exhausted"
            state["fix_loop_round"] = max_rounds
            self._save_fix_loop_state(run_root, state)

        final_status = str(state.get("status", "exhausted"))
        final_fix_loop = state.get("fix_loop", {})
        if isinstance(final_fix_loop, dict):
            final_fix_loop["rounds"] = rounds
        current_payload["fix_loop"] = final_fix_loop
        current_payload["exit_code"] = current_code
        current_payload["status"] = final_status
        current_payload["current_step"] = str(state.get("current_step", final_status))
        current_payload["fix_loop_round"] = int(state.get("fix_loop_round", len(rounds) - 1))
        current_payload["approval_required"] = False
        current_payload["artifact_root"] = str(state.get("artifact_root", _to_posix(run_root)))
        current_payload["run_id"] = str(state.get("run_id", current_payload.get("run_id", "")))
        state["last_payload"] = current_payload
        self._save_fix_loop_state(run_root, state)
        return _with_status_shape(current_payload)

    def invoke(self, tool_name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        if tool_name == "list_test_scenarios":
            return self.list_test_scenarios(arguments)
        if tool_name == "run_game_test":
            return self.run_game_test(arguments)
        if tool_name == "check_test_runner_environment":
            return self.check_test_runner_environment(arguments)
        if tool_name == "get_test_artifacts":
            return self.get_test_artifacts(arguments)
        if tool_name == "get_test_report":
            return self.get_test_report(arguments)
        if tool_name == "run_game_flow":
            return self.run_game_flow(arguments)
        if tool_name == "get_test_run_status":
            return self.get_test_run_status(arguments)
        if tool_name == "cancel_test_run":
            return self.cancel_test_run(arguments)
        if tool_name == "resume_fix_loop":
            return self.resume_fix_loop(arguments)
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
    step = str(first.get("stepId", ""))
    return {
        "step": step,
        "step_id": step,
        "category": str(first.get("category", "")),
        "expected": str(first.get("expected", "")),
        "actual": str(first.get("actual", "")),
        "artifacts": list(first.get("artifacts", []))
        if isinstance(first.get("artifacts", []), list)
        else [],
    }


def _report_exit_codes(report_payload: dict[str, Any]) -> tuple[int | None, int | None]:
    if not isinstance(report_payload, dict):
        return None, None
    effective = report_payload.get("effective_exit_code")
    if effective is None:
        effective = report_payload.get("exitCode")
    process = report_payload.get("process_exit_code")
    try:
        effective = int(effective) if effective is not None else None
    except (TypeError, ValueError):
        effective = None
    try:
        process = int(process) if process is not None else None
    except (TypeError, ValueError):
        process = None
    return effective, process


def _to_posix(value: str | Path) -> str:
    return str(value).replace("\\", "/")


def _common_windows_godot_candidates() -> list[str]:
    out: list[str] = []
    roots = [
        os.environ.get("GODOT_HOME", ""),
        os.environ.get("ProgramFiles", ""),
        os.environ.get("ProgramFiles(x86)", ""),
        os.path.expandvars(r"%LOCALAPPDATA%\Programs"),
    ]
    for root in roots:
        root = str(root).strip()
        if not root:
            continue
        root_path = Path(root)
        if not root_path.exists():
            continue
        direct = [
            root_path / "Godot" / "godot.exe",
            root_path / "Godot" / "godot4.exe",
        ]
        for item in direct:
            if item.exists() and item.is_file():
                out.append(str(item))
        for pattern in ("Godot*.exe", "godot*.exe"):
            for item in root_path.glob(pattern):
                if item.is_file():
                    out.append(str(item))
            for item in (root_path / "Godot").glob(pattern):
                if item.is_file():
                    out.append(str(item))
    dedup: list[str] = []
    seen: set[str] = set()
    for item in out:
        key = item.lower()
        if key in seen:
            continue
        seen.add(key)
        dedup.append(item)
    return dedup


def _resolve_godot_bin(
    requested: str,
    strict: bool = False,
    allow_unresolved: bool = False,
) -> tuple[str, dict[str, Any]]:
    requested = requested.strip()
    candidates: list[str] = []
    if requested:
        candidates.append(requested)
    env_bin = str(os.environ.get("GODOT_BIN", "")).strip()
    if env_bin:
        candidates.append(env_bin)
    candidates.extend(["godot4", "godot", "godot4.exe", "godot.exe"])
    candidates.extend(_common_windows_godot_candidates())

    tried: list[str] = []
    for candidate in candidates:
        candidate = candidate.strip()
        if not candidate:
            continue
        if candidate in tried:
            continue
        tried.append(candidate)
        p = Path(candidate)
        if p.is_absolute() and p.exists() and p.is_file():
            return candidate, {"strategy": "absolute_path_exists", "requested": requested, "tried": tried}
        resolved = shutil.which(candidate)
        if resolved:
            return resolved, {"strategy": "which", "requested": requested, "tried": tried}

    if strict and requested:
        raise AppError("INVALID_ARGUMENT", f"strict_godot_bin=true but unresolved: {requested}", {"tried": tried})
    if not allow_unresolved:
        raise AppError(
            "MISSING_GODOT_BIN",
            (
                "Unable to resolve Godot executable. Set environment variable GODOT_BIN "
                "to a valid executable path, or ensure godot4/godot is available in PATH."
            ),
            {"requested": requested, "tried": tried},
        )
    if requested:
        return requested, {"strategy": "fallback_to_requested", "requested": requested, "tried": tried}
    return "godot4", {"strategy": "default", "requested": requested, "tried": tried}


def _with_status_shape(payload: dict[str, Any]) -> dict[str, Any]:
    out = dict(payload)
    out["run_id"] = str(out.get("run_id", ""))
    out["status"] = str(out.get("status", "unknown"))
    out["current_step"] = str(out.get("current_step", ""))
    out["fix_loop_round"] = int(out.get("fix_loop_round", 0))
    out["approval_required"] = bool(out.get("approval_required", False))
    return out


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
        if args.tool in {"get_test_artifacts", "get_test_report", "get_test_run_status", "cancel_test_run", "resume_fix_loop"}:
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
