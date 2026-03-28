#!/usr/bin/env python3
"""Unified MCP adapter for game test runner."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

CORE_DIR = Path(__file__).resolve().parents[1] / "core"
MCP_DIR = Path(__file__).resolve().parent
VERSION_MANIFEST_PATH = MCP_DIR / "version_manifest.json"
if str(CORE_DIR) not in sys.path:
    sys.path.insert(0, str(CORE_DIR))

from server_errors import AppError  # noqa: E402
from server_handlers_core import CoreHandlersMixin  # noqa: E402
from server_handlers_fixloop import FixLoopHandlersMixin  # noqa: E402
from server_handlers_live import LiveHandlersMixin  # noqa: E402
from server_handlers_stepwise_support import StepwiseSupportMixin  # noqa: E402
from server_handlers_stepwise_ops import StepwiseOpsHandlersMixin  # noqa: E402
from server_handlers_stepwise_autopilot import StepwiseAutopilotHandlersMixin  # noqa: E402
from server_handlers_cursor_chat_plugin import CursorChatPluginHandlersMixin  # noqa: E402


class GameTestMcpServer(
    CoreHandlersMixin,
    FixLoopHandlersMixin,
    LiveHandlersMixin,
    StepwiseSupportMixin,
    StepwiseOpsHandlersMixin,
    StepwiseAutopilotHandlersMixin,
    CursorChatPluginHandlersMixin,
):
    """Single MCP server surface for core/fixloop/live/stepwise/chat tools."""

    TOOL_TO_METHOD: dict[str, str] = {
        "get_mcp_runtime_info": "get_mcp_runtime_info",
        "list_test_scenarios": "list_test_scenarios",
        "run_game_test": "run_game_test",
        "check_test_runner_environment": "check_test_runner_environment",
        "get_test_artifacts": "get_test_artifacts",
        "get_test_report": "get_test_report",
        "get_flow_timeline": "get_flow_timeline",
        "run_game_flow": "run_game_flow",
        "get_test_run_status": "get_test_run_status",
        "cancel_test_run": "cancel_test_run",
        "resume_fix_loop": "resume_fix_loop",
        "start_game_flow_live": "start_game_flow_live",
        "get_live_flow_progress": "get_live_flow_progress",
        "run_and_stream_flow": "run_and_stream_flow",
        "start_stepwise_flow": "start_stepwise_flow",
        "prepare_step": "prepare_step",
        "execute_step": "execute_step",
        "verify_step": "verify_step",
        "step_once": "step_once",
        "run_stepwise_autopilot": "run_stepwise_autopilot",
        "start_cursor_chat_plugin": "start_cursor_chat_plugin",
        "pull_cursor_chat_plugin": "pull_cursor_chat_plugin",
    }

    RELAY_ALLOWED_TOOLS: set[str] = {
        "list_test_scenarios",
        "check_test_runner_environment",
        "get_test_artifacts",
        "get_test_report",
        "get_flow_timeline",
        "get_test_run_status",
        "cancel_test_run",
        "pull_cursor_chat_plugin",
        "start_cursor_chat_plugin",
    }

    def __init__(self, default_project_root: Path) -> None:
        self.default_project_root = default_project_root.resolve()
        self.core_dir = CORE_DIR

    def _enforce_chat_relay_gate(self, tool_name: str, arguments: dict[str, Any]) -> None:
        relay_required = bool(arguments.get("chat_relay_required", False))
        if not relay_required:
            return
        if tool_name in self.RELAY_ALLOWED_TOOLS:
            return
        raise AppError(
            "CHAT_RELAY_REQUIRED",
            "chat_relay_required=true only allows cursor chat relay tools and query/cancel tools",
            {
                "tool": tool_name,
                "allowed_tools": sorted(self.RELAY_ALLOWED_TOOLS),
            },
        )

    def get_mcp_runtime_info(self, _arguments: dict[str, Any]) -> dict[str, Any]:
        manifest_payload: dict[str, Any] = {}
        if VERSION_MANIFEST_PATH.exists():
            try:
                parsed = json.loads(VERSION_MANIFEST_PATH.read_text(encoding="utf-8"))
                if isinstance(parsed, dict):
                    manifest_payload = parsed
            except json.JSONDecodeError:
                manifest_payload = {}
        current_version = str(manifest_payload.get("current_version", "")).strip()
        return {
            "server_name": "game-test-runner-mcp",
            "server_version": current_version or "dev",
            "tool_count": len(self.TOOL_TO_METHOD),
            "tools": sorted(self.TOOL_TO_METHOD.keys()),
            "relay_allowed_tools": sorted(self.RELAY_ALLOWED_TOOLS),
            "version_manifest_path": str(VERSION_MANIFEST_PATH),
            "version_manifest_loaded": bool(manifest_payload),
            "update_policy": manifest_payload.get("update_policy", {}),
            "channels": manifest_payload.get("channels", {}),
        }

    def invoke(self, tool_name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        method_name = self.TOOL_TO_METHOD.get(tool_name, "")
        if not method_name:
            raise AppError("UNSUPPORTED_TOOL", f"unsupported tool: {tool_name}")
        self._enforce_chat_relay_gate(tool_name, arguments)
        method = getattr(self, method_name, None)
        if not callable(method):
            raise AppError("INTERNAL_ERROR", f"tool handler not implemented: {tool_name}")
        return method(arguments)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Unified MCP adapter for game test runner.")
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
        if args.tool in {
            "get_test_artifacts",
            "get_test_report",
            "get_test_run_status",
            "cancel_test_run",
            "resume_fix_loop",
            "get_live_flow_progress",
            "pull_cursor_chat_plugin",
            "prepare_step",
            "execute_step",
            "verify_step",
            "step_once",
            "run_stepwise_autopilot",
            "get_flow_timeline",
        }:
            if args.run_id is not None:
                tool_args["run_id"] = args.run_id
        if args.tool in {
            "run_game_flow",
            "start_game_flow_live",
            "run_and_stream_flow",
            "start_stepwise_flow",
            "start_cursor_chat_plugin",
            "run_stepwise_autopilot",
        } and args.flow_file is not None:
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
