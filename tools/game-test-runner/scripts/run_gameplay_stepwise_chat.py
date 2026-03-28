#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _ensure_import() -> None:
    mcp_dir = _repo_root() / "tools" / "game-test-runner" / "mcp"
    if str(mcp_dir) not in sys.path:
        sys.path.insert(0, str(mcp_dir))


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _parse_ts(raw: str) -> datetime | None:
    try:
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
    except Exception:
        return None


def _delay_ms(event_utc: str, emit_utc: str) -> int | None:
    ev = _parse_ts(event_utc)
    em = _parse_ts(emit_utc)
    if ev is None or em is None:
        return None
    return int(round((em - ev).total_seconds() * 1000))


def _print_event(phase_name: str, text: str, event_utc: str = "", game_time: str = "", emit_shell_chat: bool = False) -> str:
    emit_ts = _utc_now()
    if emit_shell_chat:
        print(
            f"[CHAT][{phase_name}][emit={emit_ts}][event={event_utc}][game={game_time}] {text}",
            flush=True,
        )
    return emit_ts


def _run_one_flow(
    *,
    server: Any,
    project_root: Path,
    flow_file: Path,
    godot_bin: str,
    timeout_sec: int,
    run_id: str = "",
    phase_name: str = "",
    max_batch: int = 3,
    wait_scale: float = 1.0,
    pause_during_think: bool = True,
    resume_speed: float = 1.0,
    emit_shell_chat: bool = False,
) -> dict[str, Any]:
    audit_entries: list[dict[str, Any]] = []
    start_payload = server.start_cursor_chat_plugin(
        {
            "project_root": str(project_root),
            "flow_file": str(flow_file),
            "godot_bin": godot_bin,
            "timeout_sec": timeout_sec,
            "run_id": run_id,
            "wait_scale": float(wait_scale),
            "pause_during_think": bool(pause_during_think),
            "resume_speed": float(resume_speed),
            "chat_relay_required": True,
        }
    )
    rid = str(start_payload.get("run_id", ""))
    artifact_root = Path(str(start_payload.get("artifact_root", ""))).resolve()
    final_status = "failed"
    flow_status = "failed"
    verify_reason = ""
    total_events = 0
    while True:
        payload = server.pull_cursor_chat_plugin({"run_id": rid, "max_batch": max_batch})
        events = payload.get("events", [])
        if not isinstance(events, list):
            one = payload.get("event", {})
            events = [one] if isinstance(one, dict) and one else []
        if not events and bool(payload.get("finished", False)):
            break
        for evt in events:
            if not isinstance(evt, dict):
                continue
            total_events += 1
            text = str(evt.get("text", "")).strip()
            event_utc = str(evt.get("event_utc", evt.get("ts", ""))).strip()
            game_time = str(evt.get("game_time", "")).strip()
            emit_ts = _print_event(phase_name, text, event_utc, game_time, emit_shell_chat=emit_shell_chat)
            phase = str(evt.get("phase", "")).strip()
            status = str(evt.get("status", "")).strip()
            if phase == "next":
                if status == "failed":
                    final_status = "failed"
                    flow_status = "failed"
                    verify_reason = text
                elif "流程结束" in text:
                    final_status = "passed"
                    flow_status = "passed"
            audit_entries.append(
                {
                    "run_id": rid,
                    "phase_name": phase_name,
                    "phase": phase,
                    "step_id": str(evt.get("step_id", "")),
                    "action": str(evt.get("action", "")),
                    "progress": str(evt.get("progress", "")),
                    "status": status,
                    "text": text,
                    "event_utc": event_utc,
                    "game_time": game_time,
                    "chat_emit_ts": emit_ts,
                    "delay_ms": _delay_ms(event_utc, emit_ts),
                }
            )

    pid_exit_verified = False
    try:
        flow_report = json.loads((artifact_root / "flow_report.json").read_text(encoding="utf-8"))
        if isinstance(flow_report, dict):
            pid_exit_verified = bool(flow_report.get("pid_exit_verified", False))
    except Exception:
        pid_exit_verified = False

    return {
        "run_id": rid,
        "status": final_status,
        "flow_status": flow_status,
        "verify_reason": verify_reason,
        "pid_exit_verified": pid_exit_verified,
        "events_emitted": total_events,
        "artifact_root": str(artifact_root),
        "audit_entries": audit_entries,
    }


def _build_chat_audit(entries: list[dict[str, Any]]) -> dict[str, Any]:
    delay_values = [int(e["delay_ms"]) for e in entries if isinstance(e, dict) and e.get("delay_ms") is not None]
    grouped: dict[str, set[str]] = {}
    for e in entries:
        if not isinstance(e, dict):
            continue
        step_id = str(e.get("step_id", "")).strip()
        progress = str(e.get("progress", "")).strip()
        run_id = str(e.get("run_id", "")).strip()
        phase = str(e.get("phase", "")).strip()
        if not step_id or not progress:
            continue
        key = f"{run_id}|{progress}|{step_id}"
        grouped.setdefault(key, set()).add(phase)
    protocol_checks: list[dict[str, Any]] = []
    required = {"about_to_start", "started", "result", "verify", "next"}
    for key, got in grouped.items():
        run_id, progress, step_id = key.split("|", 2)
        protocol_checks.append(
            {
                "run_id": run_id,
                "step_id": step_id,
                "progress": progress,
                "protocol_ok": required.issubset(got),
            }
        )
    return {
        "total_events": len(entries),
        "delay_samples": len(delay_values),
        "min_delay_ms": min(delay_values) if delay_values else None,
        "max_delay_ms": max(delay_values) if delay_values else None,
        "avg_delay_ms": int(round(sum(delay_values) / len(delay_values))) if delay_values else None,
        "protocol_all_ok": all(bool(p.get("protocol_ok", False)) for p in protocol_checks) if protocol_checks else True,
        "protocol_checks": protocol_checks,
    }


def _format_chat_audit_summary(chat_audit: dict[str, Any]) -> str:
    protocol_ok = bool(chat_audit.get("protocol_all_ok", False))
    min_delay = chat_audit.get("min_delay_ms")
    max_delay = chat_audit.get("max_delay_ms")
    avg_delay = chat_audit.get("avg_delay_ms")
    return (
        f"protocol_all_ok={str(protocol_ok).lower()} "
        f"min_delay_ms={min_delay} "
        f"max_delay_ms={max_delay} "
        f"avg_delay_ms={avg_delay}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run gameplay stepwise flow with chat-first strict stages.")
    parser.add_argument("--project-root", default=str(_repo_root()))
    parser.add_argument("--godot-bin", required=True)
    parser.add_argument("--flow-file", default="")
    parser.add_argument("--timeout-sec", type=int, default=300)
    parser.add_argument("--run-id", default="")
    parser.add_argument("--output-json", default="")
    parser.add_argument("--template", action="store_true")
    parser.add_argument("--max-batch", type=int, default=3)
    parser.add_argument("--wait-scale", type=float, default=0.2)
    parser.add_argument("--resume-speed", type=float, default=6.0)
    parser.add_argument("--disable-think-pause", action="store_true")
    parser.add_argument("--emit-shell-chat", action="store_true")
    args = parser.parse_args()
    _ensure_import()
    from server import GameTestMcpServer  # pylint: disable=import-error,import-outside-toplevel

    project_root = Path(args.project_root).resolve()
    server = GameTestMcpServer(default_project_root=project_root)
    summary: dict[str, Any] = {
        "template_id": "gameplay_base_template_cursor_plugin" if args.template else "single_flow_stepwise_chat_plugin",
        "started_at": _utc_now(),
        "project_root": str(project_root),
        "godot_bin": str(args.godot_bin),
        "phases": [],
        "chat_audit_entries": [],
        "status": "running",
    }
    flows: list[tuple[str, Path]]
    if args.template:
        flows = [
            ("phase1_new_game_clean_build_save", project_root / "flows" / "base_validation_slot0_phase1.json"),
            ("phase2_continue_verify_persisted", project_root / "flows" / "base_validation_slot0_phase2.json"),
        ]
    else:
        if not args.flow_file:
            raise SystemExit("--flow-file is required when --template is not set")
        flows = [("single_flow", Path(args.flow_file).resolve())]

    for phase_name, flow_file in flows:
        if summary["status"] != "running":
            break
        result = _run_one_flow(
            server=server,
            project_root=project_root,
            flow_file=flow_file,
            godot_bin=str(args.godot_bin),
            timeout_sec=int(args.timeout_sec),
            run_id=str(args.run_id).strip(),
            phase_name=phase_name,
            max_batch=max(1, int(args.max_batch)),
            wait_scale=max(0.05, float(args.wait_scale)),
            pause_during_think=not bool(args.disable_think_pause),
            resume_speed=max(0.1, float(args.resume_speed)),
            emit_shell_chat=bool(args.emit_shell_chat),
        )
        result["phase"] = phase_name
        result["flow_file"] = str(flow_file)
        summary["phases"].append(result)
        phase_audit = result.get("audit_entries", [])
        if isinstance(phase_audit, list):
            summary["chat_audit_entries"].extend(phase_audit)
        if str(result.get("status", "")) != "passed":
            summary["status"] = "failed"
    if summary["status"] == "running":
        summary["status"] = "passed"
    summary["chat_audit"] = _build_chat_audit(summary["chat_audit_entries"])
    summary["chat_audit_summary"] = _format_chat_audit_summary(summary["chat_audit"])
    summary["finished_at"] = _utc_now()
    output_json = str(args.output_json).strip()
    if not output_json:
        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        prefix = "gameplay_base_template_cursor_plugin" if args.template else "gameplay_stepwise_chat_plugin"
        output_json = str(project_root / "artifacts" / "test-runs" / f"{prefix}_{ts}.json")
    out_path = Path(output_json).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    audit_path = Path(str(out_path) + ".chat_audit.json")
    audit_path.write_text(json.dumps(summary.get("chat_audit_entries", []), ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"SUMMARY_JSON={out_path}", flush=True)
    print(f"CHAT_AUDIT_JSON={audit_path}", flush=True)
    print(f"CHAT_AUDIT_SUMMARY={summary['chat_audit_summary']}", flush=True)
    return 0 if str(summary["status"]) == "passed" else 3


if __name__ == "__main__":
    raise SystemExit(main())
