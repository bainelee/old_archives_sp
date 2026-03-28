from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from driver_client import DriverClient
from server_errors import AppError


class CursorChatPluginHandlersMixin:
    """Project-level Cursor chat plugin layer for chat-first stepwise relay."""

    @staticmethod
    def _plugin_state_path(run_root: Path) -> Path:
        return run_root / "cursor_chat_plugin_state.json"

    def _load_plugin_state(self, run_root: Path) -> dict[str, Any]:
        p = self._plugin_state_path(run_root)
        if not p.exists():
            return {}
        try:
            obj = json.loads(p.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
        return obj if isinstance(obj, dict) else {}

    def _save_plugin_state(self, run_root: Path, state: dict[str, Any]) -> None:
        self._plugin_state_path(run_root).write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")

    def _plugin_set_game_speed(self, run_root: Path, speed: float) -> bool:
        stepwise_state = self._load_stepwise_state(run_root)
        if not isinstance(stepwise_state, dict):
            return False
        driver_dir = Path(str(stepwise_state.get("driver_dir", "")).strip())
        if not str(driver_dir):
            return False
        try:
            client = DriverClient(base_dir=driver_dir)
            resp = client.send_and_wait(action="setGameTimeSpeed", params={"speed": float(speed)}, timeout_sec=5.0)
            return str(resp.get("status", "")) == "ok"
        except Exception:
            return False

    def _plugin_set_global_pause(self, run_root: Path, paused: bool) -> bool:
        stepwise_state = self._load_stepwise_state(run_root)
        if not isinstance(stepwise_state, dict):
            return False
        driver_dir = Path(str(stepwise_state.get("driver_dir", "")).strip())
        if not str(driver_dir):
            return False
        try:
            client = DriverClient(base_dir=driver_dir)
            resp = client.send_and_wait(action="setGlobalPause", params={"paused": bool(paused)}, timeout_sec=5.0)
            return str(resp.get("status", "")) == "ok"
        except Exception:
            return False

    def start_cursor_chat_plugin(self, arguments: dict[str, Any]) -> dict[str, Any]:
        started = self.start_stepwise_flow(arguments)
        run_id = str(started.get("run_id", "")).strip()
        if not run_id:
            raise AppError("INVALID_STATE", "start_stepwise_flow returned empty run_id")
        run_root = self._resolve_run_root(run_id, {"run_id": run_id})
        state = {
            "version": 1,
            "run_id": run_id,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "finished": False,
            "phase_state": "need_prepare",
            "active_step": {},
            "active_step_index": -1,
            "active_step_total": 0,
            "queue": [],
            "emitted": 0,
            "pause_during_think": bool(arguments.get("pause_during_think", True)),
            "paused_by_plugin": False,
            "resume_speed": float(arguments.get("resume_speed", 1.0) or 1.0),
        }
        if bool(state["pause_during_think"]):
            if self._plugin_set_global_pause(run_root, paused=True):
                state["paused_by_plugin"] = True
        self._save_plugin_state(run_root, state)
        return {
            "run_id": run_id,
            "status": "running",
            "mode": "cursor_chat_plugin",
            "total_steps": int(started.get("total_steps", 0)),
            "next_step": started.get("next_step", {}),
            "artifact_root": started.get("artifact_root", ""),
            "pause_during_think": bool(state.get("pause_during_think", False)),
        }

    @staticmethod
    def _build_plugin_stage5_event(verify: dict[str, Any], active_step: dict[str, Any], game_time: str = "") -> dict[str, Any]:
        verified = bool(verify.get("verified", False))
        status = str(verify.get("status", "running"))
        step_id = str(active_step.get("id", ""))
        action = str(active_step.get("action", ""))
        step_total = int(verify.get("step_total", 0))
        step_index = int(verify.get("step_index", -1))
        progress = f"{step_index + 1}/{step_total}" if step_total > 0 and step_index >= 0 else ""
        if verified and status != "finished":
            next_step = verify.get("next_step", {}) if isinstance(verify.get("next_step"), dict) else {}
            text = f"通过验证进入下一步：{str(next_step.get('id', '')).strip() or 'next'}"
            st = "passed"
        elif verified and status == "finished":
            text = "通过验证，流程结束"
            st = "passed"
        else:
            text = "验证失败，立即停止"
            st = "failed"
        event_utc = datetime.now(timezone.utc).isoformat()
        return {
            "phase": "next",
            "text": text,
            "step_id": step_id,
            "action": action,
            "progress": progress,
            "status": st,
            "detail": "",
            "event_utc": event_utc,
            "game_time": str(game_time or ""),
            "ts": event_utc,
        }

    def pull_cursor_chat_plugin(self, arguments: dict[str, Any]) -> dict[str, Any]:
        run_id = str(arguments.get("run_id", "")).strip()
        if not run_id:
            raise AppError("INVALID_ARGUMENT", "run_id is required")
        max_batch = int(arguments.get("max_batch", 1))
        if max_batch <= 0:
            raise AppError("INVALID_ARGUMENT", "max_batch must be >= 1")
        max_batch = min(max_batch, 20)
        run_root = self._resolve_run_root(run_id, arguments)
        state = self._load_plugin_state(run_root)
        if not state:
            raise AppError("NOT_FOUND", f"cursor chat plugin state missing for run_id: {run_id}")
        queue = state.get("queue", [])
        if not isinstance(queue, list):
            queue = []

        if (not queue) and (not bool(state.get("finished", False))):
            phase_state = str(state.get("phase_state", "need_prepare"))
            active_step = state.get("active_step", {})
            if not isinstance(active_step, dict):
                active_step = {}

            if phase_state == "need_prepare":
                prepare = self.prepare_step({"run_id": run_id})
                if str(prepare.get("status", "")) == "finished":
                    state["finished"] = True
                    state["phase_state"] = "done"
                else:
                    step = prepare.get("step", {}) if isinstance(prepare.get("step"), dict) else {}
                    state["active_step"] = step
                    state["active_step_index"] = int(prepare.get("step_index", -1))
                    state["active_step_total"] = int(prepare.get("step_total", 0))
                    about_events = [
                        e
                        for e in (prepare.get("chat_events", []) if isinstance(prepare.get("chat_events"), list) else [])
                        if isinstance(e, dict) and str(e.get("phase", "")) == "about_to_start"
                    ]
                    if not about_events:
                        about_events = [
                            self._build_stepwise_chat_event(
                                phase="about_to_start",
                                step_id=str(step.get("id", "")),
                                action=str(step.get("action", "")),
                                step_index=int(state.get("active_step_index", -1)),
                                step_total=int(state.get("active_step_total", 0)),
                                status="running",
                            )
                        ]
                    queue.extend(about_events)
                    state["phase_state"] = "need_started"

            elif phase_state == "need_started":
                step_id = str(active_step.get("id", ""))
                action = str(active_step.get("action", ""))
                started_event = self._build_stepwise_chat_event(
                    phase="started",
                    step_id=step_id,
                    action=action,
                    step_index=int(state.get("active_step_index", -1)),
                    step_total=int(state.get("active_step_total", 0)),
                    status="running",
                )
                queue.append(started_event)
                state["phase_state"] = "need_execute"

            elif phase_state == "need_execute":
                if bool(state.get("pause_during_think", False)) and bool(state.get("paused_by_plugin", False)):
                    resume_speed = float(state.get("resume_speed", 1.0) or 1.0)
                    unpaused = self._plugin_set_global_pause(run_root, paused=False)
                    speed_ok = self._plugin_set_game_speed(run_root, speed=resume_speed)
                    if unpaused and speed_ok:
                        state["paused_by_plugin"] = False
                execute = self.execute_step({"run_id": run_id})
                result_events = [
                    e
                    for e in (execute.get("chat_events", []) if isinstance(execute.get("chat_events"), list) else [])
                    if isinstance(e, dict) and str(e.get("phase", "")) == "result"
                ]
                if not result_events:
                    result_events = [
                        self._build_stepwise_chat_event(
                            phase="result",
                            step_id=str(active_step.get("id", "")),
                            action=str(active_step.get("action", "")),
                            step_index=int(state.get("active_step_index", -1)),
                            step_total=int(state.get("active_step_total", 0)),
                            status="running",
                            detail="执行完成",
                            game_time=str(execute.get("game_time", "")),
                        )
                    ]
                queue.extend(result_events)
                if str(active_step.get("action", "")) == "setGameTimeSpeed":
                    params = active_step.get("params", {})
                    if isinstance(params, dict):
                        speed = float(params.get("speed", 0.0) or 0.0)
                        if speed > 0:
                            state["resume_speed"] = speed
                if bool(state.get("pause_during_think", False)):
                    if self._plugin_set_global_pause(run_root, paused=True):
                        state["paused_by_plugin"] = True
                state["phase_state"] = "need_verify"

            elif phase_state == "need_verify":
                verify = self.verify_step({"run_id": run_id})
                verify_events = [
                    e
                    for e in (verify.get("chat_events", []) if isinstance(verify.get("chat_events"), list) else [])
                    if isinstance(e, dict) and str(e.get("phase", "")) == "verify"
                ]
                queue.extend(verify_events)
                game_time = str(verify_events[0].get("game_time", "")) if verify_events else ""
                queue.append(self._build_plugin_stage5_event(verify=verify, active_step=active_step, game_time=game_time))
                if str(verify.get("status", "")) == "finished":
                    state["finished"] = True
                    state["phase_state"] = "done"
                    state["active_step"] = {}
                else:
                    state["phase_state"] = "need_prepare"
                    state["active_step"] = {}
                    state["active_step_index"] = -1
                    state["active_step_total"] = 0

            state["queue"] = queue
            self._save_plugin_state(run_root, state)

        if not queue:
            return {
                "run_id": run_id,
                "event": {},
                "events": [],
                "remaining": 0,
                "finished": bool(state.get("finished", False)),
                "emitted": int(state.get("emitted", 0)),
                "max_batch": max_batch,
                "paused_by_plugin": bool(state.get("paused_by_plugin", False)),
            }

        events: list[dict[str, Any]] = []
        take = min(max_batch, len(queue))
        for _ in range(take):
            event = queue.pop(0)
            if isinstance(event, dict):
                events.append(event)
        state["queue"] = queue
        state["emitted"] = int(state.get("emitted", 0)) + len(events)
        self._save_plugin_state(run_root, state)
        return {
            "run_id": run_id,
            "event": events[0] if events else {},
            "events": events,
            "remaining": len(queue),
            "finished": bool(state.get("finished", False)) and len(queue) == 0,
            "emitted": int(state.get("emitted", 0)),
            "max_batch": max_batch,
            "paused_by_plugin": bool(state.get("paused_by_plugin", False)),
        }
