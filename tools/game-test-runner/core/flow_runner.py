#!/usr/bin/env python3
"""Execute gameplay debug flows and emit structured flow report."""

from __future__ import annotations

import argparse
import hashlib
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from flows.exploration_gameplay_flow_v1 import FLOW_ID, get_flow_definition
from runner import GameTestRunner, RunRequest, RunResult


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _duration_ms(start_monotonic: float) -> int:
    return int((time.monotonic() - start_monotonic) * 1000)


def _assertion_record(name: str, ok: bool, expected: str, actual: str) -> dict:
    return {"name": name, "ok": ok, "expected": expected, "actual": actual}


def _resolve_flow(flow_id: str) -> dict:
    if flow_id == FLOW_ID:
        return get_flow_definition()
    raise ValueError(f"unsupported flow_id: {flow_id}")


def _wait_for_file(path: Path, timeout_sec: float, poll_interval_sec: float) -> bool:
    deadline = time.monotonic() + timeout_sec
    while time.monotonic() <= deadline:
        if path.exists():
            return True
        time.sleep(poll_interval_sec)
    return path.exists()


def _run_scenario_step(
    step: dict,
    project_root: Path,
    godot_bin: str,
    timeout_sec: int,
    dry_run: bool,
) -> tuple[dict, Optional[RunResult], Optional[Path]]:
    started = time.monotonic()
    runner = GameTestRunner(project_root=project_root)
    req = RunRequest(
        system=str(step["system"]),
        project_root=project_root,
        scenario=str(step["scenario"]),
        timeout_sec=timeout_sec,
        godot_bin=godot_bin,
        dry_run=dry_run,
        screenshot_prefix=str(step.get("screenshot_prefix", "")).strip() or None,
    )
    result = runner.run(req)
    run_root = Path(result.artifact_root)

    assertions = [
        _assertion_record(
            "run_status_equals_finished",
            result.status == "finished",
            "finished",
            result.status,
        ),
        _assertion_record(
            "run_exit_code_equals_0",
            result.exit_code == 0,
            "0",
            str(result.exit_code),
        ),
    ]
    ok = all(a["ok"] for a in assertions)
    status = "passed" if ok else "failed"
    artifacts = [
        str(run_root / "report.json"),
        str(run_root / "run_meta.json"),
        str(run_root / "logs" / "stdout.log"),
        str(run_root / "logs" / "stderr.log"),
    ]
    step_result = {
        "name": str(step["name"]),
        "status": status,
        "duration_ms": _duration_ms(started),
        "wait_condition": step.get("wait_condition", {}),
        "assertions": assertions,
        "artifacts": artifacts,
        "run_id": result.run_id,
    }
    if not ok:
        step_result["error"] = result.error or "scenario step failed"
    return step_result, result, run_root


def _wait_for_file_step(step: dict, run_root: Path) -> dict:
    started = time.monotonic()
    relative = str(step["path"])
    target = run_root / relative
    wait_ok = _wait_for_file(
        target,
        timeout_sec=float(step.get("timeout_sec", 5)),
        poll_interval_sec=float(step.get("poll_interval_sec", 0.2)),
    )
    assertions = [
        _assertion_record("file_exists", wait_ok, "exists", "exists" if wait_ok else "missing")
    ]
    status = "passed" if wait_ok else "failed"
    step_result = {
        "name": str(step["name"]),
        "status": status,
        "duration_ms": _duration_ms(started),
        "wait_condition": step.get("wait_condition", {}),
        "assertions": assertions,
        "artifacts": [str(target)],
    }
    if not wait_ok:
        step_result["error"] = f"timeout waiting for file: {relative}"
    return step_result


def _assert_files_step(step: dict, run_root: Path) -> dict:
    started = time.monotonic()
    assertions: list[dict] = []
    artifacts: list[str] = []
    for assertion in step.get("assertions", []):
        rel_path = str(assertion.get("path", ""))
        abs_path = run_root / rel_path
        exists = abs_path.exists()
        assertions.append(
            _assertion_record(
                f"file_exists:{rel_path}",
                exists,
                "exists",
                "exists" if exists else "missing",
            )
        )
        artifacts.append(str(abs_path))
    ok = all(a["ok"] for a in assertions) if assertions else False
    step_result = {
        "name": str(step["name"]),
        "status": "passed" if ok else "failed",
        "duration_ms": _duration_ms(started),
        "wait_condition": step.get("wait_condition", {}),
        "assertions": assertions,
        "artifacts": artifacts,
    }
    if not ok:
        missing = [a["name"] for a in assertions if not a["ok"]]
        step_result["error"] = f"missing required artifacts: {', '.join(missing)}"
    return step_result


def _assert_log_markers_step(step: dict, run_root: Path) -> dict:
    started = time.monotonic()
    rel_path = str(step.get("path", "logs/stdout.log"))
    log_path = run_root / rel_path
    assertions: list[dict] = []
    artifacts: list[str] = [str(log_path)]
    marker_hits: list[str] = []

    if not log_path.exists():
        step_result = {
            "name": str(step.get("name", "assert_log_markers")),
            "status": "failed",
            "duration_ms": _duration_ms(started),
            "wait_condition": step.get("wait_condition", {}),
            "assertions": [
                _assertion_record(
                    f"log_exists:{rel_path}",
                    False,
                    "exists",
                    "missing",
                )
            ],
            "artifacts": artifacts,
            "error": f"log file missing: {rel_path}",
        }
        return step_result

    log_text = log_path.read_text(encoding="utf-8", errors="replace")
    for marker in step.get("markers", []):
        marker_text = str(marker)
        ok = marker_text in log_text
        assertions.append(
            _assertion_record(
                f"log_contains:{marker_text}",
                ok,
                marker_text,
                "found" if ok else "missing",
            )
        )
        if ok:
            marker_hits.append(marker_text)

    marker_excerpt_path = run_root / "logs" / "flow_markers_excerpt.txt"
    marker_excerpt_path.write_text("\n".join(marker_hits).strip() + "\n", encoding="utf-8")
    artifacts.append(str(marker_excerpt_path))

    ok = all(a["ok"] for a in assertions) if assertions else False
    step_result = {
        "name": str(step.get("name", "assert_log_markers")),
        "status": "passed" if ok else "failed",
        "duration_ms": _duration_ms(started),
        "wait_condition": step.get("wait_condition", {}),
        "assertions": assertions,
        "artifacts": artifacts,
    }
    if not ok:
        missing = [a["name"] for a in assertions if not a["ok"]]
        step_result["error"] = f"missing required log markers: {', '.join(missing)}"
    return step_result


def _assert_files_distinct_step(step: dict, run_root: Path) -> dict:
    started = time.monotonic()
    rel_files = [str(x) for x in step.get("files", [])]
    assertions: list[dict] = []
    artifacts: list[str] = []
    digests: dict[str, str] = {}

    for rel_path in rel_files:
        abs_path = run_root / rel_path
        artifacts.append(str(abs_path))
        if not abs_path.exists():
            assertions.append(
                _assertion_record(
                    f"file_exists:{rel_path}",
                    False,
                    "exists",
                    "missing",
                )
            )
            continue
        payload = abs_path.read_bytes()
        digests[rel_path] = hashlib.sha256(payload).hexdigest()
        assertions.append(
            _assertion_record(
                f"file_exists:{rel_path}",
                True,
                "exists",
                "exists",
            )
        )

    digest_values = list(digests.values())
    if len(digest_values) >= 2:
        unique_count = len(set(digest_values))
        distinct_ok = unique_count == len(digest_values)
        assertions.append(
            _assertion_record(
                "files_are_distinct",
                distinct_ok,
                "all files differ",
                f"unique_hash_count={unique_count} total={len(digest_values)}",
            )
        )
    else:
        assertions.append(
            _assertion_record(
                "files_are_distinct",
                False,
                "at least two existing files",
                f"existing={len(digest_values)}",
            )
        )

    digest_report_path = run_root / "screenshots" / "flow_step_hashes.json"
    digest_report_path.write_text(json.dumps(digests, ensure_ascii=False, indent=2), encoding="utf-8")
    artifacts.append(str(digest_report_path))

    ok = all(a["ok"] for a in assertions)
    step_result = {
        "name": str(step.get("name", "assert_files_distinct")),
        "status": "passed" if ok else "failed",
        "duration_ms": _duration_ms(started),
        "wait_condition": step.get("wait_condition", {}),
        "assertions": assertions,
        "artifacts": artifacts,
    }
    if not ok:
        failures = [a["name"] for a in assertions if not a["ok"]]
        step_result["error"] = f"distinct file assertion failed: {', '.join(failures)}"
    return step_result


def execute_flow(
    flow_id: str,
    project_root: Path,
    godot_bin: str,
    timeout_sec: int,
    dry_run: bool,
) -> tuple[dict, int]:
    flow = _resolve_flow(flow_id)
    started_at = _utc_now_iso()
    steps: list[dict] = []
    run_id = ""
    run_root: Optional[Path] = None
    overall_status = "passed"

    for step in flow.get("steps", []):
        step_type = str(step.get("type", ""))
        if step_type == "run_scenario":
            step_result, result, run_root = _run_scenario_step(
                step=step,
                project_root=project_root,
                godot_bin=godot_bin,
                timeout_sec=timeout_sec,
                dry_run=dry_run,
            )
            run_id = result.run_id if result else run_id
        elif step_type == "wait_for_file":
            if run_root is None:
                step_result = {
                    "name": str(step.get("name", "wait_for_file")),
                    "status": "failed",
                    "duration_ms": 0,
                    "wait_condition": step.get("wait_condition", {}),
                    "assertions": [],
                    "artifacts": [],
                    "error": "run artifact root is not available before wait step",
                }
            else:
                step_result = _wait_for_file_step(step=step, run_root=run_root)
        elif step_type == "assert_files":
            if run_root is None:
                step_result = {
                    "name": str(step.get("name", "assert_files")),
                    "status": "failed",
                    "duration_ms": 0,
                    "wait_condition": step.get("wait_condition", {}),
                    "assertions": [],
                    "artifacts": [],
                    "error": "run artifact root is not available before assert step",
                }
            else:
                step_result = _assert_files_step(step=step, run_root=run_root)
        elif step_type == "assert_log_markers":
            if run_root is None:
                step_result = {
                    "name": str(step.get("name", "assert_log_markers")),
                    "status": "failed",
                    "duration_ms": 0,
                    "wait_condition": step.get("wait_condition", {}),
                    "assertions": [],
                    "artifacts": [],
                    "error": "run artifact root is not available before marker step",
                }
            else:
                step_result = _assert_log_markers_step(step=step, run_root=run_root)
        elif step_type == "assert_files_distinct":
            if run_root is None:
                step_result = {
                    "name": str(step.get("name", "assert_files_distinct")),
                    "status": "failed",
                    "duration_ms": 0,
                    "wait_condition": step.get("wait_condition", {}),
                    "assertions": [],
                    "artifacts": [],
                    "error": "run artifact root is not available before distinct-file step",
                }
            else:
                step_result = _assert_files_distinct_step(step=step, run_root=run_root)
        else:
            step_result = {
                "name": str(step.get("name", "unknown_step")),
                "status": "failed",
                "duration_ms": 0,
                "wait_condition": step.get("wait_condition", {}),
                "assertions": [],
                "artifacts": [],
                "error": f"unsupported step type: {step_type}",
            }

        steps.append(step_result)
        if step_result["status"] != "passed":
            overall_status = "failed"
            break

    finished_at = _utc_now_iso()
    flow_report = {
        "flow_id": flow_id,
        "status": overall_status,
        "started_at": started_at,
        "finished_at": finished_at,
        "run_id": run_id,
        "steps": steps,
    }

    if run_root is None:
        # Fallback path to avoid silent success when run step never executed.
        fallback_root = project_root / "artifacts" / "test-runs" / f"flow_{flow_id}_{int(time.time())}"
        fallback_root.mkdir(parents=True, exist_ok=True)
        run_root = fallback_root

    flow_report_path = run_root / "flow_report.json"
    flow_report_path.write_text(json.dumps(flow_report, ensure_ascii=False, indent=2), encoding="utf-8")
    return (
        {
            "flow_id": flow_id,
            "status": overall_status,
            "run_id": run_id,
            "artifact_root": str(run_root),
            "flow_report": str(flow_report_path),
        },
        0 if overall_status == "passed" else 1,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run gameplay debug flow.")
    parser.add_argument("--flow-id", default=FLOW_ID, help="Flow template id")
    parser.add_argument("--project-root", required=True, help="Project root path")
    parser.add_argument("--godot-bin", required=True, help="Godot executable path")
    parser.add_argument("--timeout-sec", type=int, default=120, help="Per run step timeout")
    parser.add_argument("--dry-run", action="store_true", help="Skip actual Godot run")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    payload, code = execute_flow(
        flow_id=args.flow_id,
        project_root=Path(args.project_root).resolve(),
        godot_bin=args.godot_bin,
        timeout_sec=args.timeout_sec,
        dry_run=args.dry_run,
    )
    print(json.dumps(payload, ensure_ascii=False))
    return code


if __name__ == "__main__":
    raise SystemExit(main())

