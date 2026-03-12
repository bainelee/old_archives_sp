#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""导出 Cursor agent 对话到指定目录，按对话顺序编号，中文对话使用中文文件名。"""

import json
import os
import re
from pathlib import Path
from datetime import datetime

# 路径配置
TRANSCRIPTS_DIR = Path(r"C:\Users\baine\.cursor\projects\d-GODOT-Test-old-archives-sp\agent-transcripts")
OUTPUT_DIR = Path(r"C:\Users\baine\Desktop\old_archives_agents_chat")
MAX_TITLE_LEN = 16  # 文件名中的标题最大字符数


def has_chinese(text: str) -> bool:
    """判断文本是否包含中文字符。"""
    return bool(re.search(r"[\u4e00-\u9fff]", text))


def extract_user_query_text(full_text: str) -> str:
    """从用户消息中提取实际查询内容，去除 cursor_commands、git_status 等系统块。"""
    text = full_text
    # 移除 <cursor_commands>...</cursor_commands>
    text = re.sub(r"<cursor_commands>[\s\S]*?<\/cursor_commands>", "", text, flags=re.IGNORECASE)
    # 移除 <git_status>...</git_status>
    text = re.sub(r"<git_status>[\s\S]*?<\/git_status>", "", text, flags=re.IGNORECASE)
    # 移除 <attached_files>...</attached_files>
    text = re.sub(r"<attached_files>[\s\S]*?<\/attached_files>", "", text, flags=re.IGNORECASE)
    # 尝试提取 <user_query>...</user_query> 内容
    m = re.search(r"<user_query>\s*([\s\S]*?)\s*<\/user_query>", text, re.IGNORECASE)
    if m:
        return m.group(1).strip()
    # 尝试提取 @ 引用后的第一行
    lines = text.strip().split("\n")
    for line in lines:
        line = line.strip()
        if not line or line.startswith("<") or line.startswith("---"):
            continue
        # 跳过纯命令如 /gitpush
        if line.startswith("/") and len(line) < 30:
            continue
        return line
    return text.strip()[:200] if text.strip() else "未命名对话"


def derive_title(jsonl_path: Path) -> str:
    """从 jsonl 第一条用户消息推导对话标题。"""
    try:
        with open(jsonl_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                if obj.get("role") == "user":
                    content = obj.get("message", {}).get("content", [])
                    if not content:
                        break
                    full_text = ""
                    for item in content:
                        if isinstance(item, dict) and item.get("type") == "text":
                            full_text += item.get("text", "")
                    extracted = extract_user_query_text(full_text)
                    if not extracted:
                        return "未命名对话"
                    # 取首行或前若干个字符
                    first_line = extracted.split("\n")[0].strip()
                    first_line = first_line[:MAX_TITLE_LEN] if len(first_line) > MAX_TITLE_LEN else first_line
                    # 若提取结果过短、纯命令或 @ 引用式标题，则用更通用的名称
                    if len(first_line) < 2:
                        return "对话" if has_chinese(full_text) else "Chat"
                    if first_line.startswith("/") and len(first_line) < 25:
                        return "Git推送" if "gitpush" in first_line.lower() else "对话"
                    if first_line.startswith("@") and len(first_line) < 25:
                        # @file 引用，尝试从文件名取有意义部分，否则用「对话」
                        return "对话"
                    return first_line
    except Exception:
        pass
    return "未命名对话"


def sanitize_filename(name: str) -> str:
    """替换 Windows 文件名非法字符。"""
    invalid = r'\/:*?"<>|'
    for c in invalid:
        name = name.replace(c, "_")
    name = re.sub(r"\s+", " ", name)
    return name.strip() or "未命名"


def extract_text_from_message(msg: dict) -> str:
    """从 message 的 content 中提取文本。"""
    content = msg.get("content", [])
    texts = []
    for item in content:
        if isinstance(item, dict) and item.get("type") == "text":
            texts.append(item.get("text", ""))
    return "\n".join(texts)


def jsonl_to_markdown(jsonl_path: Path) -> str:
    """将 jsonl 转为可读的 Markdown 格式。"""
    lines = ["# Agent 对话导出\n", f"导出时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"]
    try:
        with open(jsonl_path, "r", encoding="utf-8") as f:
            idx = 0
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                role = obj.get("role", "unknown")
                text = extract_text_from_message(obj.get("message", {}))
                if not text:
                    continue
                idx += 1
                role_label = "用户" if role == "user" else "助手"
                lines.append(f"\n## [{idx}] {role_label}\n\n")
                lines.append(text)
                lines.append("\n\n")
    except Exception as e:
        lines.append(f"\n读取错误: {e}\n")
    return "".join(lines)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 收集父级对话（排除 subagents）
    parent_transcripts = []
    for item in TRANSCRIPTS_DIR.iterdir():
        if not item.is_dir():
            continue
        uuid = item.name
        jsonl_file = item / f"{uuid}.jsonl"
        if jsonl_file.exists():
            parent_transcripts.append((jsonl_file, uuid))

    # 按文件修改时间升序排序（最早 = 01）
    parent_transcripts.sort(key=lambda x: x[0].stat().st_mtime)

    exported = []
    for i, (jsonl_path, uuid) in enumerate(parent_transcripts, 1):
        title = derive_title(jsonl_path)
        safe_title = sanitize_filename(title)
        if has_chinese(title) or has_chinese(safe_title):
            filename = f"{i:02d}-{safe_title}.md"
        else:
            filename = f"{i:02d}-{safe_title}.md" if safe_title else f"{i:02d}-对话.md"

        out_path = OUTPUT_DIR / filename
        md_content = jsonl_to_markdown(jsonl_path)
        out_path.write_text(md_content, encoding="utf-8")
        exported.append((i, filename, title))

    print(f"已导出 {len(exported)} 个对话到: {OUTPUT_DIR}")
    for num, fname, title in exported:
        print(f"  {num:02d}: {fname}")


if __name__ == "__main__":
    main()
