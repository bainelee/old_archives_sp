#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _ensure_import() -> None:
    mcp_dir = _repo_root() / "tools" / "game-test-runner" / "mcp"
    sys.path.insert(0, str(mcp_dir))


def _load_screenshot_step_map(flow_file: Path) -> dict[str, str]:
    try:
        payload = json.loads(flow_file.read_text(encoding="utf-8"))
    except Exception:  # pylint: disable=broad-except
        return {}
    raw_steps = payload.get("steps", []) if isinstance(payload, dict) else []
    if not isinstance(raw_steps, list):
        return {}
    out: dict[str, str] = {}
    for step in raw_steps:
        if not isinstance(step, dict):
            continue
        if str(step.get("action", "")).strip() != "screenshot":
            continue
        sid = str(step.get("id", "")).strip()
        name = str(step.get("name", "")).strip()
        if sid and name:
            out[sid] = name
    return out


def _format_event_line(event: dict, screenshot_path: str = "") -> str:
    kind = str(event.get("kind", "")).strip()
    text = str(event.get("text", "")).strip()
    progress = str(event.get("progress", "")).strip()
    ts = str(event.get("ts", "")).strip()
    if kind == "ready":
        prefix = "即将开始"
        return f"[{ts}] {prefix}: {text} ({progress})"
    if kind == "started":
        prefix = "开始执行"
        return f"[{ts}] {prefix}: {text} ({progress})"
    if kind == "completed":
        status = str(event.get("status", "")).strip().lower()
        if status == "passed":
            prefix = "已完成(验证通过)"
        elif status:
            prefix = f"已完成(验证{status})"
        else:
            prefix = "已完成(已验证)"
        line = f"[{ts}] {prefix}: {text} ({progress})"
        if screenshot_path:
            line += f" | 截图: {screenshot_path}"
        return line
    # Fallback for unexpected kinds.
    return f"[{ts}] 事件: {text} ({progress})"


def main() -> int:
    parser = argparse.ArgumentParser(description="Bridge live flow events for chat relay.")
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--flow-file", required=True)
    parser.add_argument("--godot-bin", required=True)
    parser.add_argument("--poll-interval-sec", type=float, default=0.25)
    parser.add_argument("--event-limit", type=int, default=1)
    args = parser.parse_args()

    _ensure_import()
    from server import GameTestMcpServer  # pylint: disable=import-error,import-outside-toplevel

    project_root = Path(args.project_root).resolve()
    flow_file = Path(args.flow_file).resolve()
    screenshot_step_map = _load_screenshot_step_map(flow_file)
    server = GameTestMcpServer(default_project_root=project_root)
    start_payload = server.start_game_flow_live(
        {
            "project_root": str(project_root),
            "flow_file": str(flow_file),
            "godot_bin": args.godot_bin,
        }
    )
    run_id = str(start_payload.get("run_id", "")).strip()
    if not run_id:
        print(json.dumps({"type": "error", "message": "empty run_id"}, ensure_ascii=False), flush=True)
        return 1
    print(json.dumps({"type": "run_started", "run_id": run_id}, ensure_ascii=False), flush=True)

    cursor = -1
    while True:
        payload = server.get_live_flow_progress(
            {
                "run_id": run_id,
                "view": "chat",
                "chat_mode": "short",
                "event_since": cursor,
                "event_limit": int(args.event_limit),
            }
        )
        step_events = payload.get("step_events", {}) if isinstance(payload, dict) else {}
        new_events = step_events.get("new_events", []) if isinstance(step_events, dict) else []
        if isinstance(new_events, list):
            for event in new_events:
                if not isinstance(event, dict):
                    continue
                screenshot_path = ""
                if str(event.get("kind", "")) == "completed" and str(event.get("action", "")) == "screenshot":
                    step_id = str(event.get("step_id", "")).strip()
                    shot_name = screenshot_step_map.get(step_id, "").strip()
                    if shot_name:
                        screenshot_path = str((project_root / "artifacts" / "test-runs" / run_id / "screenshots" / f"{shot_name}.png").as_posix())
                print(
                    json.dumps(
                        {"type": "event", "line": _format_event_line(event, screenshot_path), "event": event, "screenshot_path": screenshot_path},
                        ensure_ascii=False,
                    ),
                    flush=True,
                )
        next_cursor = step_events.get("cursor", cursor) if isinstance(step_events, dict) else cursor
        try:
            cursor = int(next_cursor)
        except (TypeError, ValueError):
            pass
        state = str(payload.get("state", "")).strip()
        if state == "finished":
            final_status = str(payload.get("flow_status", "")).strip()
            if final_status in {"", "running"}:
                # flow_report may lag behind state for a short moment; retry briefly for stable final status.
                retry_deadline = time.monotonic() + 2.0
                while time.monotonic() < retry_deadline:
                    time.sleep(0.1)
                    payload = server.get_live_flow_progress(
                        {
                            "run_id": run_id,
                            "view": "chat",
                            "chat_mode": "short",
                            "event_since": cursor,
                            "event_limit": 1,
                        }
                    )
                    final_status = str(payload.get("flow_status", "")).strip()
                    if final_status and final_status != "running":
                        break
            print(
                json.dumps({"type": "run_finished", "run_id": run_id, "flow_status": final_status or "unknown"}, ensure_ascii=False),
                flush=True,
            )
            return 0
        time.sleep(max(0.05, float(args.poll_interval_sec)))


if __name__ == "__main__":
    raise SystemExit(main())

