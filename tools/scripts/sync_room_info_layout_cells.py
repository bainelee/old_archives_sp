#!/usr/bin/env python3
"""
根据 grid_x/grid_y 与 3d_size 生成 layout_cells（馆内坐标：room_00 左下角为 (0,0)）。
并修正西侧竖井三间 grid_x：-4 -> -3，使与 room_01 共格边连通。

用法（仓库根目录）:
  python tools/scripts/sync_room_info_layout_cells.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROOM_INFO = ROOT / "datas" / "room_info.json"

SIZE_TO_GRID = {
    "base": (2, 1),
    "small": (1, 1),
    "tall": (2, 2),
    "small_tall": (1, 2),
    "long": (4, 1),
}

WEST_PASS_IDS = frozenset({"room_pass_1", "room_pass_2", "room_pass_3"})
# 西翼 F2 与竖井 pass_2 同一层须格相邻；原 grid 偏西一格导致与主图断开
WEST_WING_GRID_X = {
    "room_09": -7,
    "room_10": -9,
}


def grid_size(room: dict) -> tuple[int, int]:
    sz = room.get("3d_size") or room.get("size_3d") or "base"
    if not isinstance(sz, str):
        sz = str(sz)
    return SIZE_TO_GRID.get(sz.lower().strip(), (1, 1))


def cells_world(room: dict) -> list[tuple[int, int]]:
    gx = int(room["grid_x"])
    gy = int(room["grid_y"])
    w, h = grid_size(room)
    return [(gx + dx, gy + dy) for dx in range(w) for dy in range(h)]


def main() -> None:
    data = json.loads(ROOM_INFO.read_text(encoding="utf-8"))
    rooms: list[dict] = data.get("rooms", [])
    for r in rooms:
        rid = r.get("id", "")
        if rid in WEST_PASS_IDS and int(r.get("grid_x", 0)) == -4:
            r["grid_x"] = -3
        if rid in WEST_WING_GRID_X:
            r["grid_x"] = WEST_WING_GRID_X[rid]
    room00 = next((x for x in rooms if x.get("id") == "room_00"), None)
    if not room00:
        raise SystemExit("room_00 missing")
    ox = int(room00["grid_x"])
    oy = int(room00["grid_y"])
    for r in rooms:
        if "grid_x" not in r or "grid_y" not in r:
            continue
        world = cells_world(r)
        r["layout_cells"] = [[c[0] - ox, c[1] - oy] for c in world]
    data["version"] = 3
    ROOM_INFO.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {ROOM_INFO} with layout_cells, version=3, west passes grid_x=-3.")


if __name__ == "__main__":
    main()
