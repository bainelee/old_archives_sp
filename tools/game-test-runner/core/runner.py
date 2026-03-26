#!/usr/bin/env python3
"""Minimal game test runner skeleton (Step 2)."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from scenario_registry import get_scenario_by_name


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _run_id(scenario: str) -> str:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    safe = scenario.replace(" ", "_")
    return f"{ts}_{safe}"


@dataclass
class RunRequest:
    system: str
    project_root: Path
    scenario: Optional[str] = None
    profile: str = "smoke"
    mode: str = "vm"
    timeout_sec: int = 300
    retry: int = 0
    clean_save_slots: bool = True
    godot_bin: str = "godot4"
    scene: Optional[str] = None
    extra_args: list[str] = field(default_factory=list)
    dry_run: bool = False
    screenshot_prefix: Optional[str] = None

    def normalized_scenario(self) -> str:
        if self.scenario:
            return self.scenario
        return f"{self.system}_smoke"


@dataclass
class RunResult:
    run_id: str
    status: str
    exit_code: Optional[int]
    started_at: str
    finished_at: str
    artifact_root: str
    command: list[str]
    error: Optional[str] = None
    failure_category: Optional[str] = None
    failure_details: Optional[dict] = None

    def to_report(self, request: RunRequest, artifact_index: Optional[dict] = None) -> dict:
        return {
            "runId": self.run_id,
            "status": "passed" if self.status == "finished" else "failed",
            "scenario": request.normalized_scenario(),
            "environment": {"mode": request.mode, "godotVersion": "unknown"},
            "summary": {"totalAssertions": 0, "passed": 0, "failed": 0},
            "artifactIndex": artifact_index or {},
            "failures": (
                []
                if self.status == "finished"
                else [
                    {
                        "stepId": "step_process_exec",
                        "category": self.failure_category
                        if self.failure_category
                        else ("timeout" if self.status == "timeout" else "runtime_error"),
                        "expected": "process exit code == 0",
                        "actual": self.error or f"exit code {self.exit_code}",
                        "details": self.failure_details or {},
                        "artifacts": [
                            "logs/stdout.log",
                            "logs/stderr.log",
                            "run_meta.json",
                        ] + self._visual_artifact_refs(artifact_index),
                    }
                ]
            ),
        }

    @staticmethod
    def _visual_artifact_refs(artifact_index: Optional[dict]) -> list[str]:
        if not artifact_index:
            return []
        copied = set(artifact_index.get("copiedScreenshots", []))
        refs: list[str] = []
        for name in (
            "screenshots/visual_ui_button_diff.png",
            "screenshots/visual_ui_button_diff_annotated.png",
        ):
            if name in copied:
                refs.append(name)
        return refs


class GameTestRunner:
    def __init__(self, project_root: Path, artifact_base: Optional[Path] = None) -> None:
        self.project_root = project_root.resolve()
        self.artifact_base = (
            artifact_base.resolve()
            if artifact_base
            else self.project_root / "artifacts" / "test-runs"
        )

    def _prepare_artifacts(self, run_id: str) -> Path:
        run_root = self.artifact_base / run_id
        (run_root / "screenshots").mkdir(parents=True, exist_ok=True)
        (run_root / "logs").mkdir(parents=True, exist_ok=True)
        (run_root / "save_snapshots").mkdir(parents=True, exist_ok=True)
        return run_root

    def _build_command(self, req: RunRequest) -> list[str]:
        scenario = req.normalized_scenario()
        scenario_def = get_scenario_by_name(scenario)
        scene = req.scene or (scenario_def.scene if scenario_def else None)
        cmd = [req.godot_bin, "--path", str(req.project_root)]
        if scene:
            cmd.append(scene)
        args = list(scenario_def.default_args) if scenario_def else []
        # Godot user args should be placed after `--`, otherwise `--flag` may be parsed as engine args.
        user_args = list(req.extra_args) if req.extra_args else (list(scenario_def.user_args) if scenario_def else [])
        if user_args:
            args.append("--")
            args.extend(user_args)
        cmd.extend(args)
        return cmd

    def _write_json(self, path: Path, payload: dict) -> None:
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    def _write_final_meta(self, run_root: Path, meta: dict, result: RunResult) -> None:
        final_meta = dict(meta)
        final_meta["status"] = result.status
        final_meta["finishedAt"] = result.finished_at
        final_meta["exitCode"] = result.exit_code
        if result.error:
            final_meta["error"] = result.error
        self._write_json(run_root / "run_meta.json", final_meta)

    def _read_app_name(self) -> str:
        project_file = self.project_root / "project.godot"
        if not project_file.exists():
            return "Old Archives"
        text = project_file.read_text(encoding="utf-8")
        match = re.search(r'config/name="([^"]+)"', text)
        if not match:
            return "Old Archives"
        return match.group(1).strip() or "Old Archives"

    def _resolve_user_data_dir(self) -> Optional[Path]:
        appdata = os.environ.get("APPDATA")
        if not appdata:
            return None
        app_name = self._read_app_name()
        return Path(appdata) / "Godot" / "app_userdata" / app_name

    def _copy_if_exists(self, src: Path, dst: Path) -> bool:
        if not src.exists() or not src.is_file():
            return False
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        return True

    def _collect_artifact_index(self, run_root: Path, screenshot_prefix: Optional[str] = None) -> dict:
        logs_dir = run_root / "logs"
        screenshots_dir = run_root / "screenshots"
        save_dir = run_root / "save_snapshots"
        artifact_index: dict = {
            "artifactRoot": str(run_root),
            "logsDir": str(logs_dir),
            "screenshotsDir": str(screenshots_dir),
            "saveSnapshotsDir": str(save_dir),
            "copiedLogs": [],
            "copiedScreenshots": [],
            "saveFiles": [],
            "screenshotPrefixFilter": screenshot_prefix or "",
        }

        user_data_dir = self._resolve_user_data_dir()
        if not user_data_dir:
            return artifact_index

        user_logs = user_data_dir / "logs"
        godot_log_src = user_logs / "godot.log"
        frame_log_src = user_logs / "debug_frame_overlay.txt"
        if self._copy_if_exists(godot_log_src, logs_dir / "godot.log"):
            artifact_index["copiedLogs"].append("logs/godot.log")
        if self._copy_if_exists(frame_log_src, logs_dir / "debug_frame_overlay.txt"):
            artifact_index["copiedLogs"].append("logs/debug_frame_overlay.txt")

        user_shots = user_data_dir / "test_screenshots"
        if user_shots.exists() and user_shots.is_dir():
            for shot in sorted(user_shots.glob("*.png")):
                if screenshot_prefix and not shot.name.startswith(screenshot_prefix):
                    continue
                dst = screenshots_dir / shot.name
                if self._copy_if_exists(shot, dst):
                    artifact_index["copiedScreenshots"].append(f"screenshots/{shot.name}")

        user_saves = user_data_dir / "saves"
        if user_saves.exists() and user_saves.is_dir():
            for item in sorted(user_saves.glob("*.save")):
                stat = item.stat()
                artifact_index["saveFiles"].append(
                    {
                        "name": item.name,
                        "size": stat.st_size,
                        "modifiedAt": datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat(),
                    }
                )
        self._write_json(save_dir / "save_index.json", {"files": artifact_index["saveFiles"]})
        return artifact_index

    def _detect_failure_category(self, stdout_text: str, stderr_text: str, status: str) -> Optional[str]:
        if status == "timeout":
            return "timeout"
        haystack = (stdout_text + "\n" + stderr_text).lower()
        if "visual_regression" in haystack or "[visualregressionprobetest]" in haystack:
            return "visual_regression"
        return "runtime_error"

    def _extract_visual_details(self, stderr_text: str) -> dict:
        # Example: baseline mismatch diff=0.015719 threshold=0.002000
        match = re.search(r"diff=([0-9]*\.?[0-9]+)\s+threshold=([0-9]*\.?[0-9]+)", stderr_text)
        if not match:
            return {}
        diff_value = float(match.group(1))
        threshold_value = float(match.group(2))
        return {"diff": diff_value, "threshold": threshold_value}

    def run(self, req: RunRequest) -> RunResult:
        scenario = req.normalized_scenario()
        scenario_def = get_scenario_by_name(scenario)
        effective_screenshot_prefix = (
            req.screenshot_prefix
            if req.screenshot_prefix is not None
            else (scenario_def.screenshot_prefix if scenario_def else None)
        )
        run_id = _run_id(scenario)
        run_root = self._prepare_artifacts(run_id)
        cmd = self._build_command(req)
        started_at = _utc_now_iso()

        meta = {
            "run_id": run_id,
            "status": "running",
            "system": req.system,
            "scenario": scenario,
            "profile": req.profile,
            "mode": req.mode,
            "timeoutSec": req.timeout_sec,
            "retry": req.retry,
            "projectRoot": str(req.project_root),
            "command": cmd,
            "startedAt": started_at,
            "dryRun": req.dry_run,
            "screenshotPrefix": effective_screenshot_prefix or "",
        }
        self._write_json(run_root / "run_meta.json", meta)

        if req.dry_run:
            result = RunResult(
                run_id=run_id,
                status="finished",
                exit_code=0,
                started_at=started_at,
                finished_at=_utc_now_iso(),
                artifact_root=str(run_root),
                command=cmd,
            )
            self._write_final_meta(run_root, meta, result)
            artifact_index = self._collect_artifact_index(run_root, effective_screenshot_prefix)
            self._write_json(run_root / "report.json", result.to_report(req, artifact_index))
            (run_root / "report.md").write_text(
                f"# Test Report\n\n- run_id: `{run_id}`\n- status: `passed`\n- mode: `{req.mode}`\n- dry_run: `true`\n",
                encoding="utf-8",
            )
            return result

        attempts = max(req.retry, 0) + 1
        last_result: Optional[RunResult] = None
        for attempt in range(1, attempts + 1):
            try:
                proc = subprocess.run(
                    cmd,
                    cwd=str(req.project_root),
                    capture_output=True,
                    text=True,
                    timeout=req.timeout_sec,
                    check=False,
                )
                (run_root / "logs" / "stdout.log").write_text(proc.stdout or "", encoding="utf-8")
                (run_root / "logs" / "stderr.log").write_text(proc.stderr or "", encoding="utf-8")
                status = "finished" if proc.returncode == 0 else "failed"
                err = None if status == "finished" else f"non-zero exit code on attempt {attempt}"
                category = None
                if status != "finished":
                    category = self._detect_failure_category(proc.stdout or "", proc.stderr or "", status)
                details: dict = {}
                if category == "visual_regression":
                    details = self._extract_visual_details(proc.stderr or "")
                    if details:
                        err = (
                            f"visual baseline mismatch diff={details['diff']:.6f} "
                            f"threshold={details['threshold']:.6f}"
                        )
                last_result = RunResult(
                    run_id=run_id,
                    status=status,
                    exit_code=proc.returncode,
                    started_at=started_at,
                    finished_at=_utc_now_iso(),
                    artifact_root=str(run_root),
                    command=cmd,
                    error=err,
                    failure_category=category,
                    failure_details=details,
                )
                if status == "finished":
                    break
            except subprocess.TimeoutExpired:
                last_result = RunResult(
                    run_id=run_id,
                    status="timeout",
                    exit_code=None,
                    started_at=started_at,
                    finished_at=_utc_now_iso(),
                    artifact_root=str(run_root),
                    command=cmd,
                    error=f"process timed out on attempt {attempt}",
                    failure_category="timeout",
                    failure_details={},
                )
            except FileNotFoundError as exc:
                (run_root / "logs" / "stdout.log").write_text("", encoding="utf-8")
                (run_root / "logs" / "stderr.log").write_text(str(exc), encoding="utf-8")
                last_result = RunResult(
                    run_id=run_id,
                    status="failed",
                    exit_code=None,
                    started_at=started_at,
                    finished_at=_utc_now_iso(),
                    artifact_root=str(run_root),
                    command=cmd,
                    error=f"executable not found on attempt {attempt}: {exc}",
                    failure_category="runtime_error",
                    failure_details={},
                )
                break
            except OSError as exc:
                (run_root / "logs" / "stdout.log").write_text("", encoding="utf-8")
                (run_root / "logs" / "stderr.log").write_text(str(exc), encoding="utf-8")
                last_result = RunResult(
                    run_id=run_id,
                    status="failed",
                    exit_code=None,
                    started_at=started_at,
                    finished_at=_utc_now_iso(),
                    artifact_root=str(run_root),
                    command=cmd,
                    error=f"os error on attempt {attempt}: {exc}",
                    failure_category="runtime_error",
                    failure_details={},
                )
                break

        assert last_result is not None
        self._write_final_meta(run_root, meta, last_result)
        artifact_index = self._collect_artifact_index(run_root, effective_screenshot_prefix)
        self._write_json(run_root / "report.json", last_result.to_report(req, artifact_index))
        (run_root / "report.md").write_text(
            "\n".join(
                [
                    "# Test Report",
                    "",
                    f"- run_id: `{last_result.run_id}`",
                    f"- status: `{'passed' if last_result.status == 'finished' else 'failed'}`",
                    f"- mode: `{req.mode}`",
                    f"- exit_code: `{last_result.exit_code}`",
                    f"- error: `{last_result.error or ''}`",
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        return last_result
