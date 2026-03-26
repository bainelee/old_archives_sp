#!/usr/bin/env python3
"""CLI entry for the minimal game test runner skeleton."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from runner import GameTestRunner, RunRequest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run minimal game test session.")
    parser.add_argument("--system", required=True, help="System name, e.g. exploration")
    parser.add_argument("--project-root", required=True, help="Project root path")
    parser.add_argument("--scenario", default=None, help="Scenario name")
    parser.add_argument("--profile", default="smoke", help="Run profile")
    parser.add_argument("--mode", default="vm", choices=["vm", "local", "headless"])
    parser.add_argument("--timeout-sec", type=int, default=300)
    parser.add_argument("--retry", type=int, default=0)
    parser.add_argument("--godot-bin", default="godot4")
    parser.add_argument("--scene", default=None, help="Godot scene path, e.g. res://...")
    parser.add_argument("--artifact-root", default=None, help="Override artifact root directory")
    parser.add_argument("--extra-arg", action="append", default=[], help="Extra command arg")
    parser.add_argument("--dry-run", action="store_true", help="Skip process execution")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    project_root = Path(args.project_root).resolve()
    artifact_root = Path(args.artifact_root).resolve() if args.artifact_root else None

    req = RunRequest(
        system=args.system,
        project_root=project_root,
        scenario=args.scenario,
        profile=args.profile,
        mode=args.mode,
        timeout_sec=args.timeout_sec,
        retry=args.retry,
        godot_bin=args.godot_bin,
        scene=args.scene,
        extra_args=args.extra_arg,
        dry_run=args.dry_run,
    )
    runner = GameTestRunner(project_root=project_root, artifact_base=artifact_root)
    result = runner.run(req)
    print(
        json.dumps(
            {
                "run_id": result.run_id,
                "status": result.status,
                "artifact_root": result.artifact_root,
                "exit_code": result.exit_code,
            },
            ensure_ascii=False,
        )
    )
    return 0 if result.status == "finished" else 1


if __name__ == "__main__":
    raise SystemExit(main())
