#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
import unicodedata


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


def _hhmmss(raw: str) -> str:
    ts = _parse_ts(raw)
    if ts is None:
        return ""
    return ts.strftime("%H:%M:%S")


def _has_cjk(text: str) -> bool:
    for ch in text:
        if not ch.strip():
            continue
        name = unicodedata.name(ch, "")
        if "CJK" in name or "HIRAGANA" in name or "KATAKANA" in name or "HANGUL" in name:
            return True
    return False


def _split_text_lines(text: str, max_len: int) -> list[str]:
    raw = str(text or "").strip()
    if not raw:
        return [""]
    lines: list[str] = []
    cursor = 0
    while cursor < len(raw):
        lines.append(raw[cursor : cursor + max_len])
        cursor += max_len
    return lines


def _normalize_shell_text(text: str) -> list[str]:
    raw = str(text or "").strip()
    if not raw:
        return [""]
    max_len = 30 if _has_cjk(raw) else 60
    return _split_text_lines(raw, max_len=max_len)


def _print_event(phase_name: str, text: str, event_utc: str = "", game_time: str = "", emit_shell_chat: bool = False) -> tuple[str, list[str]]:
    emit_ts = _utc_now()
    normalized_lines = _normalize_shell_text(text)
    emit_short = _hhmmss(emit_ts)
    event_short = _hhmmss(event_utc)
    if emit_shell_chat:
        print(f"[emit={emit_short}][event={event_short}][game={game_time}]", flush=True)
        for line in normalized_lines:
            print(line, flush=True)
    return emit_ts, normalized_lines


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
    empty_poll_timeout_sec: float = 20.0,
    max_silent_sec: float = 10.0,
    chat_protocol_mode: str = "three_phase",
    pause_policy: str = "strict",
    user_data_dir: str = "",
) -> dict[str, Any]:
    audit_entries: list[dict[str, Any]] = []
    start_args: dict[str, Any] = {
        "project_root": str(project_root),
        "flow_file": str(flow_file),
        "godot_bin": godot_bin,
        "timeout_sec": timeout_sec,
        "run_id": run_id,
        "wait_scale": float(wait_scale),
        "pause_during_think": bool(pause_during_think),
        "resume_speed": float(resume_speed),
        "chat_relay_required": True,
        "chat_protocol_mode": str(chat_protocol_mode or "three_phase"),
        "pause_policy": str(pause_policy or "strict"),
    }
    udd = str(user_data_dir or "").strip()
    if udd:
        start_args["user_data_dir"] = udd
    start_payload = server.start_cursor_chat_plugin(start_args)
    rid = str(start_payload.get("run_id", ""))
    artifact_root = Path(str(start_payload.get("artifact_root", ""))).resolve()
    final_status = "failed"
    flow_status = "failed"
    verify_reason = ""
    total_events = 0
    ack_seq = 0
    empty_poll_started = datetime.now(timezone.utc)
    last_output_at = datetime.now(timezone.utc)
    while True:
        payload = server.pull_cursor_chat_plugin({"run_id": rid, "max_batch": max_batch, "ack_seq": ack_seq})
        events = payload.get("events", [])
        if not isinstance(events, list):
            one = payload.get("event", {})
            events = [one] if isinstance(one, dict) and one else []
        if not events and bool(payload.get("finished", False)):
            break
        if not events and not bool(payload.get("finished", False)):
            elapsed_empty = (datetime.now(timezone.utc) - empty_poll_started).total_seconds()
            silent_elapsed = (datetime.now(timezone.utc) - last_output_at).total_seconds()
            if silent_elapsed >= max(2.0, float(max_silent_sec)):
                return {
                    "run_id": rid,
                    "status": "failed",
                    "flow_status": "failed",
                    "verify_reason": f"step output silent timeout after {int(silent_elapsed)}s",
                    "pid_exit_verified": False,
                    "events_emitted": total_events,
                    "artifact_root": str(artifact_root),
                    "audit_entries": audit_entries,
                }
            if elapsed_empty >= max(2.0, float(empty_poll_timeout_sec)):
                return {
                    "run_id": rid,
                    "status": "failed",
                    "flow_status": "failed",
                    "verify_reason": f"broadcast idle timeout after {int(elapsed_empty)}s",
                    "pid_exit_verified": False,
                    "events_emitted": total_events,
                    "artifact_root": str(artifact_root),
                    "audit_entries": audit_entries,
                }
            continue
        empty_poll_started = datetime.now(timezone.utc)
        for evt in events:
            if not isinstance(evt, dict):
                continue
            total_events += 1
            seq = int(evt.get("seq", 0) or 0)
            text = str(evt.get("text", "")).strip()
            event_utc = str(evt.get("event_utc", evt.get("ts", ""))).strip()
            game_time = str(evt.get("game_time", "")).strip()
            emit_ts, normalized_lines = _print_event(
                phase_name, text, event_utc, game_time, emit_shell_chat=emit_shell_chat
            )
            last_output_at = datetime.now(timezone.utc)
            phase = str(evt.get("phase", "")).strip()
            status = str(evt.get("status", "")).strip()
            if phase == "verify":
                if status == "failed":
                    final_status = "failed"
                    flow_status = "failed"
                    verify_reason = text
            audit_entries.append(
                {
                    "run_id": rid,
                    "seq": seq,
                    "phase_name": phase_name,
                    "phase": phase,
                    "step_id": str(evt.get("step_id", "")),
                    "action": str(evt.get("action", "")),
                    "progress": str(evt.get("progress", "")),
                    "status": status,
                    "text": text,
                    "shell_lines": normalized_lines,
                    "event_utc": event_utc,
                    "game_time": game_time,
                    "chat_emit_ts": emit_ts,
                    "delay_ms": _delay_ms(event_utc, emit_ts),
                    "requires_unpaused": bool(evt.get("requires_unpaused", False)),
                    "paused_by_plugin": bool(evt.get("paused_by_plugin", False)),
                    "auto_snapshot_highrisk": bool(evt.get("auto_snapshot_highrisk", False)),
                    "runtime_window": evt.get("runtime_window", {}) if isinstance(evt.get("runtime_window", {}), dict) else {},
                    "step_enter_runtime": (
                        evt.get("step_enter_runtime", {}) if isinstance(evt.get("step_enter_runtime", {}), dict) else {}
                    ),
                    "step_exit_runtime": (
                        evt.get("step_exit_runtime", {}) if isinstance(evt.get("step_exit_runtime", {}), dict) else {}
                    ),
                }
            )
            if seq > ack_seq:
                ack_seq = seq

    pid_exit_verified = False
    try:
        flow_report = json.loads((artifact_root / "flow_report.json").read_text(encoding="utf-8"))
        if isinstance(flow_report, dict):
            pid_exit_verified = bool(flow_report.get("pid_exit_verified", False))
            flow_status = "passed" if str(flow_report.get("status", "")).strip() == "passed" else "failed"
            final_status = flow_status
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
    required = {"started", "result", "verify"}
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
    pause_samples = [e for e in entries if isinstance(e, dict)]
    paused_true = [e for e in pause_samples if bool(e.get("paused_by_plugin", False))]
    strict_pause_candidates = [
        e
        for e in pause_samples
        if str(e.get("phase", "")) == "verify" and not bool(e.get("requires_unpaused", False))
    ]
    strict_pause_hits = [e for e in strict_pause_candidates if bool(e.get("paused_by_plugin", False))]
    ignored_runtime_samples: list[float] = []
    for e in pause_samples:
        if str(e.get("phase", "")) != "verify":
            continue
        window = e.get("runtime_window", {})
        if not isinstance(window, dict):
            continue
        value = window.get("ignored_runtime_hours")
        if isinstance(value, (int, float)):
            ignored_runtime_samples.append(float(value))
    highrisk_samples = [e for e in pause_samples if bool(e.get("auto_snapshot_highrisk", False))]
    return {
        "total_events": len(entries),
        "delay_samples": len(delay_values),
        "min_delay_ms": min(delay_values) if delay_values else None,
        "max_delay_ms": max(delay_values) if delay_values else None,
        "avg_delay_ms": int(round(sum(delay_values) / len(delay_values))) if delay_values else None,
        "protocol_all_ok": all(bool(p.get("protocol_ok", False)) for p in protocol_checks) if protocol_checks else True,
        "protocol_checks": protocol_checks,
        "paused_by_plugin_true_samples": len(paused_true),
        "paused_by_plugin_total_samples": len(pause_samples),
        "paused_by_plugin_hit_ratio": (
            round(float(len(paused_true)) / float(len(pause_samples)), 4) if pause_samples else None
        ),
        "strict_pause_candidates": len(strict_pause_candidates),
        "strict_pause_hits": len(strict_pause_hits),
        "strict_pause_hit_ratio": (
            round(float(len(strict_pause_hits)) / float(len(strict_pause_candidates)), 4)
            if strict_pause_candidates
            else None
        ),
        "highrisk_snapshot_samples": len(highrisk_samples),
        "ignored_runtime_samples": len(ignored_runtime_samples),
        "ignored_runtime_hours_total": round(sum(ignored_runtime_samples), 6) if ignored_runtime_samples else 0.0,
        "ignored_runtime_hours_max": round(max(ignored_runtime_samples), 6) if ignored_runtime_samples else 0.0,
    }


def _line_length_ok(entries: list[dict[str, Any]]) -> tuple[bool, list[dict[str, Any]]]:
    violations: list[dict[str, Any]] = []
    for item in entries:
        if not isinstance(item, dict):
            continue
        lines = item.get("shell_lines", [])
        if not isinstance(lines, list):
            continue
        for idx, line in enumerate(lines):
            text = str(line or "")
            limit = 30 if _has_cjk(text) else 60
            if len(text) > limit:
                violations.append(
                    {
                        "run_id": str(item.get("run_id", "")),
                        "phase_name": str(item.get("phase_name", "")),
                        "step_id": str(item.get("step_id", "")),
                        "line_index": idx,
                        "line_length": len(text),
                        "line_limit": limit,
                        "line": text,
                    }
                )
    return len(violations) == 0, violations


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
    parser.add_argument(
        "--godot-bin",
        nargs="?",
        const="",
        default="",
        help="Godot 可执行文件路径；可省略本参数或传空字符串，从 GODOT_BIN 或 tools/game-test-runner/config/godot_executable.json 解析。",
    )
    parser.add_argument("--flow-file", default="")
    parser.add_argument("--timeout-sec", type=int, default=300)
    parser.add_argument("--run-id", default="")
    parser.add_argument("--output-json", default="")
    parser.add_argument("--template", action="store_true")
    parser.add_argument("--max-batch", type=int, default=3)
    parser.add_argument("--wait-scale", type=float, default=1.0)
    parser.add_argument("--resume-speed", type=float, default=1.0)
    parser.add_argument("--disable-think-pause", action="store_true")
    parser.add_argument(
        "--emit-shell-chat",
        action="store_true",
        help="Print chat events to shell (default on). Kept for wrapper scripts; redundant if --no-emit-shell-chat is not set.",
    )
    parser.add_argument(
        "--no-emit-shell-chat",
        action="store_true",
        help="Disable shell mirror. Non-default; only when silent runs are explicitly allowed (see docs/design/99-tools/14-mcp-core-invariants.md).",
    )
    parser.add_argument("--empty-poll-timeout-sec", type=float, default=20.0)
    parser.add_argument("--max-silent-sec", type=float, default=10.0)
    parser.add_argument("--allow-incomplete-broadcast", action="store_true")
    parser.add_argument("--chat-protocol-mode", default="three_phase")
    parser.add_argument("--pause-policy", default="strict")
    parser.add_argument("--user-data-dir", default="", help="Shared Godot user data dir (e.g. basic data reconcile)")
    args = parser.parse_args()
    if bool(args.emit_shell_chat) and bool(args.no_emit_shell_chat):
        raise SystemExit("Cannot use both --emit-shell-chat and --no-emit-shell-chat")
    emit_shell_chat = not bool(args.no_emit_shell_chat)
    _ensure_import()
    from server import GameTestMcpServer  # pylint: disable=import-error,import-outside-toplevel
    from server_common import resolve_godot_bin  # pylint: disable=import-error,import-outside-toplevel

    project_root = Path(args.project_root).resolve()

    requested_godot = str(args.godot_bin or "").strip()
    resolved_godot, godot_resolution = resolve_godot_bin(
        requested=requested_godot,
        strict=False,
        allow_unresolved=False,
        project_root=project_root,
    )
    server = GameTestMcpServer(default_project_root=project_root)
    summary: dict[str, Any] = {
        "template_id": "gameplay_base_template_cursor_plugin" if args.template else "single_flow_stepwise_chat_plugin",
        "started_at": _utc_now(),
        "project_root": str(project_root),
        "godot_bin": resolved_godot,
        "godot_bin_requested": requested_godot,
        "godot_bin_resolution": godot_resolution,
        "phases": [],
        "chat_audit_entries": [],
        "status": "running",
    }
    flows: list[tuple[str, Path]]
    if args.template:
        gp = project_root / "flows" / "suites" / "regression" / "gameplay"
        flows = [
            ("phase1_basic_gameplay_two_rooms_save", gp / "basic_gameplay_slot0_phase1.json"),
            ("phase2_basic_gameplay_continue_verify", gp / "basic_gameplay_slot0_phase2.json"),
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
            godot_bin=str(resolved_godot),
            timeout_sec=int(args.timeout_sec),
            run_id=str(args.run_id).strip(),
            phase_name=phase_name,
            max_batch=max(1, int(args.max_batch)),
            wait_scale=1.0,
            pause_during_think=not bool(args.disable_think_pause),
            resume_speed=max(0.1, float(args.resume_speed)),
            emit_shell_chat=emit_shell_chat,
            empty_poll_timeout_sec=max(2.0, float(args.empty_poll_timeout_sec)),
            max_silent_sec=max(2.0, float(args.max_silent_sec)),
            chat_protocol_mode=str(args.chat_protocol_mode or "three_phase"),
            pause_policy=str(args.pause_policy or "strict"),
            user_data_dir=str(args.user_data_dir or "").strip(),
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
    length_ok, length_violations = _line_length_ok(summary["chat_audit_entries"])
    summary["chat_audit"]["line_length_ok"] = length_ok
    summary["chat_audit"]["line_length_violations"] = length_violations
    if len(summary["chat_audit_entries"]) == 0:
        summary["status"] = "failed"
        summary["broadcast_error"] = "no chat events emitted"
    if not bool(args.allow_incomplete_broadcast):
        if not bool(summary["chat_audit"].get("protocol_all_ok", False)):
            summary["status"] = "failed"
            summary["broadcast_error"] = "chat protocol incomplete"
        if not bool(summary["chat_audit"].get("line_length_ok", False)):
            summary["status"] = "failed"
            summary["broadcast_error"] = "chat line length violation"
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
