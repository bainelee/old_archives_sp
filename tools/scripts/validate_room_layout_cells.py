#!/usr/bin/env python3
"""
校验 room_info.json：由 layout_cells 派生坐标相邻，从 room_00 做 BFS，
断言所有带 grid 的房间 id 在同一连通分量。

用法（仓库根目录）:
  python tools/scripts/validate_room_layout_cells.py
失败时退出码 1，并打印通俗说明。
"""
from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROOM_INFO = ROOT / "datas" / "room_info.json"


def manhattan_adjacent(a: tuple[int, int], b: tuple[int, int]) -> bool:
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1


def rooms_adjacent(cells_a: set[tuple[int, int]], cells_b: set[tuple[int, int]]) -> bool:
    for x in cells_a:
        for y in cells_b:
            if manhattan_adjacent(x, y):
                return True
    return False


def main() -> int:
    data = json.loads(ROOM_INFO.read_text(encoding="utf-8"))
    rooms: list[dict] = data.get("rooms", [])
    ids: list[str] = []
    id_cells: dict[str, set[tuple[int, int]]] = {}
    for r in rooms:
        if "grid_x" not in r or "grid_y" not in r:
            continue
        rid = str(r.get("id", ""))
        if not rid:
            continue
        lc = r.get("layout_cells")
        if not isinstance(lc, list) or not lc:
            print(f"错误：房间 {rid} 缺少 layout_cells，无法按格校验连通性。", file=sys.stderr)
            return 1
        cells: set[tuple[int, int]] = set()
        for pair in lc:
            if isinstance(pair, (list, tuple)) and len(pair) >= 2:
                cells.add((int(pair[0]), int(pair[1])))
        if not cells:
            print(f"错误：房间 {rid} 的 layout_cells 为空。", file=sys.stderr)
            return 1
        ids.append(rid)
        id_cells[rid] = cells

    if "room_00" not in id_cells:
        print("错误：缺少 room_00。", file=sys.stderr)
        return 1

    neighbors: dict[str, list[str]] = {i: [] for i in ids}
    for i, rid_a in enumerate(ids):
        for rid_b in ids[i + 1 :]:
            if rooms_adjacent(id_cells[rid_a], id_cells[rid_b]):
                neighbors[rid_a].append(rid_b)
                neighbors[rid_b].append(rid_a)

    start = "room_00"
    seen: set[str] = {start}
    q: deque[str] = deque([start])
    while q:
        u = q.popleft()
        for v in neighbors.get(u, []):
            if v not in seen:
                seen.add(v)
                q.append(v)

    missing = [rid for rid in ids if rid not in seen]
    if missing:
        print(
            "错误：从 room_00 沿「格相邻」无法到达下列房间，清理解锁图会断成多块：",
            file=sys.stderr,
        )
        print(", ".join(sorted(missing)), file=sys.stderr)
        return 1

    print(f"通过：共 {len(ids)} 间带网格房间，从 room_00 格相邻 BFS 全部可达。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
