#!/usr/bin/env python3
"""Run gameplay flows through TestDriver-enabled runner."""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from flow_parser import parse_flow_file
from runner import GameTestRunner, RunRequest


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _replace_vars(value: Any, env: dict[str, Any]) -> Any:
    if isinstance(value, str):
        out = value
        for k, v in env.items():
            out = out.replace("${%s}" % k, str(v))
        return out
    if isinstance(value, list):
        return [_replace_vars(x, env) for x in value]
    if isinstance(value, dict):
        return {k: _replace_vars(v, env) for k, v in value.items()}
    return value


def _expand_steps(flow: dict[str, Any], flow_file: Path, inherited_env: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    env = dict(inherited_env or {})
    env.update(flow.get("env", {}) if isinstance(flow.get("env", {}), dict) else {})
    out: list[dict[str, Any]] = []
    base_dir = flow_file.parent
    for step in flow.get("steps", []):
        resolved_step = _replace_vars(step, env)
        if str(resolved_step.get("action", "")) == "runSubflow":
            subfile = base_dir / str(resolved_step.get("file", ""))
            subflow = parse_flow_file(subfile)
            sub_env = dict(env)
            if isinstance(resolved_step.get("env", {}), dict):
                sub_env.update(resolved_step.get("env", {}))
            out.extend(_expand_steps(subflow, subfile, inherited_env=sub_env))
            continue
        out.append(resolved_step)
    return out


def _resolve_step_timeout_sec(step: dict[str, Any], default_timeout_sec: int) -> int:
    step_timeout = int(step.get("timeoutSec", default_timeout_sec))
    if str(step.get("action", "")).strip() != "wait":
        return step_timeout

    # Keep driver timeout >= wait condition timeout (plus small polling buffer).
    until_cfg = step.get("until", {})
    timeout_ms = int(step.get("timeoutMs", 0))
    if isinstance(until_cfg, dict):
        timeout_ms = max(timeout_ms, int(until_cfg.get("timeoutMs", 0)))
    if timeout_ms <= 0:
        return step_timeout

    wait_timeout_sec = (timeout_ms + 999) // 1000 + 2
    return max(step_timeout, wait_timeout_sec)


def _to_driver_steps(expanded_steps: list[dict[str, Any]], default_timeout_sec: int) -> list[dict[str, Any]]:
    driver_steps: list[dict[str, Any]] = []
    for step in expanded_steps:
        action = str(step.get("action", "")).strip()
        if not action:
            continue
        params = dict(step)
        params.pop("id", None)
        params.pop("action", None)
        params.pop("timeoutSec", None)
        driver_steps.append(
            {
                "id": step.get("id", ""),
                "action": action,
                "params": params,
                "timeoutSec": _resolve_step_timeout_sec(step, default_timeout_sec),
            }
        )
    return driver_steps


def execute_flow_file(
    flow_file: Path,
    project_root: Path,
    godot_bin: str,
    timeout_sec: int,
    dry_run: bool,
    driver_ready_timeout_sec: int | None = None,
    driver_no_activity_timeout_sec: int | None = None,
) -> tuple[dict, int]:
    flow = parse_flow_file(flow_file)
    flow_steps = _expand_steps(flow, flow_file)
    default_step_timeout_sec = int(flow.get("flowStepTimeoutSec", 15))
    driver_steps = _to_driver_steps(flow_steps, default_timeout_sec=default_step_timeout_sec)
    system = str(flow.get("system", "exploration"))
    scene = flow.get("scene")
    scenario = flow.get("scenario")
    screenshot_prefix = str(flow.get("screenshotPrefix", "")).strip() or None

    req = RunRequest(
        system=system,
        project_root=project_root,
        scenario=str(scenario) if scenario else None,
        profile=str(flow.get("profile", "flow")),
        mode=str(flow.get("mode", "local")),
        timeout_sec=timeout_sec,
        retry=int(flow.get("retry", 0)),
        godot_bin=godot_bin,
        scene=str(scene) if scene else None,
        dry_run=dry_run,
        screenshot_prefix=screenshot_prefix,
        enable_test_driver=True,
        flow_steps=driver_steps,
        flow_step_timeout_sec=default_step_timeout_sec,
        driver_ready_timeout_sec=(
            min(20, int(driver_ready_timeout_sec))
            if driver_ready_timeout_sec is not None
            else min(20, int(flow.get("driverReadyTimeoutSec", 20)))
        ),
        driver_no_activity_timeout_sec=(
            int(driver_no_activity_timeout_sec)
            if driver_no_activity_timeout_sec is not None
            else int(flow.get("driverNoActivityTimeoutSec", 5))
        ),
    )

    started_at = _utc_now_iso()
    runner = GameTestRunner(project_root=project_root)
    result = runner.run(req)
    finished_at = _utc_now_iso()
    run_root = Path(result.artifact_root)
    flow_report = {
        "flow_id": flow.get("flowId", flow_file.stem),
        "flow_file": str(flow_file),
        "status": "passed" if result.status == "finished" else "failed",
        "started_at": started_at,
        "finished_at": finished_at,
        "run_id": result.run_id,
        "driver_steps": driver_steps,
    }
    flow_report_path = run_root / "flow_report.json"
    flow_report_path.write_text(json.dumps(flow_report, ensure_ascii=False, indent=2), encoding="utf-8")
    payload = {
        "flow_id": flow_report["flow_id"],
        "status": flow_report["status"],
        "run_id": result.run_id,
        "artifact_root": str(run_root),
        "flow_report": str(flow_report_path),
    }
    return payload, 0 if result.status == "finished" else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run gameplay flow file.")
    parser.add_argument("--flow-file", required=True, help="Flow file path (json/yaml)")
    parser.add_argument("--project-root", required=True, help="Project root path")
    parser.add_argument("--godot-bin", required=True, help="Godot executable path")
    parser.add_argument("--timeout-sec", type=int, default=300, help="Whole run timeout")
    parser.add_argument("--dry-run", action="store_true", help="Skip actual Godot run")
    parser.add_argument(
        "--driver-ready-timeout-sec",
        type=int,
        default=None,
        help="Override TestDriver ready timeout seconds",
    )
    parser.add_argument(
        "--driver-no-activity-timeout-sec",
        type=int,
        default=None,
        help="Override no-activity kill timeout seconds",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    payload, code = execute_flow_file(
        flow_file=Path(args.flow_file).resolve(),
        project_root=Path(args.project_root).resolve(),
        godot_bin=args.godot_bin,
        timeout_sec=args.timeout_sec,
        dry_run=args.dry_run,
        driver_ready_timeout_sec=args.driver_ready_timeout_sec,
        driver_no_activity_timeout_sec=args.driver_no_activity_timeout_sec,
    )
    print(json.dumps(payload, ensure_ascii=False))
    return code


if __name__ == "__main__":
    raise SystemExit(main())

