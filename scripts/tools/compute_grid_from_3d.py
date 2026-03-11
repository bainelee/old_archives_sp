#!/usr/bin/env python3
"""
从 archives_base_0.tscn 3D 场景读取房间位置，按 room_volume 计算 grid_x、grid_y，
并更新 room_info.json。

约定：
- 场景中房间 pivot 为底面中心（RoomReferenceGrid 约定）
- 房间局部 X: [-hx, hx]，Y: [0, 2*hy]，其中 hx = xR*0.25, hy = yR*0.25（米）
- 1 layout grid 单元格 = 5.25 米（使 long=21m 为 4 格，且 room_01 与 room_pass_0 邻接）
- grid_x = floor(world_left / GRID_CELL_METERS), grid_y = floor(world_bottom / GRID_CELL_METERS)

用法：python scripts/tools/compute_grid_from_3d.py
"""

import json
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
ARCHIVES_TSCN = PROJECT_ROOT / "scenes" / "game" / "archives_base_0.tscn"
ROOMS_DIR = PROJECT_ROOT / "scenes" / "rooms" / "archives_rooms"
ROOM_INFO_JSON = PROJECT_ROOT / "datas" / "room_info.json"
# 5.25m 使 long(21m)=4 格，且 room_01 右边界与 room_pass_0 左边界在 10.5/11.5 处共线
GRID_CELL_METERS = 5.25


def parse_transform(line: str) -> tuple[float, float, float] | None:
    """解析 Transform3D 行，返回 (x, y, z) 平移分量。"""
    # Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, tx, ty, tz)
    m = re.search(r"Transform3D\([^)]+,\s*([-\d.e]+),\s*([-\d.e]+),\s*([-\d.e]+)\)", line)
    if m:
        return (float(m.group(1)), float(m.group(2)), float(m.group(3)))
    return None


def parse_archives_scene(path: Path) -> dict[str, tuple[float, float, float]]:
    """解析 archives_base_0.tscn，返回 room_id -> (x, y, z) 世界坐标。"""
    text = path.read_text(encoding="utf-8")
    result: dict[str, tuple[float, float, float]] = {}
    current_node = None
    for line in text.splitlines():
        # [node name="room_XX" ...] 或 [node name="room_pass_N" ...] 或 [node name="room_hall_N" ...]
        m = re.match(r'\[node name="([^"]+)"', line)
        if m:
            name = m.group(1)
            if name.startswith("room_") and name not in ("room_out_block_down", "room_out_block_up", "room_out_block_left", "room_out_block_right"):
                current_node = name
            else:
                current_node = None
            continue
        if current_node and "transform" in line.lower():
            t = parse_transform(line)
            if t:
                result[current_node] = t
            current_node = None
    return result


def get_room_volume(room_id: str) -> tuple[float, float, float]:
    """从房间场景获取 room_volume (xR, yR, zR)，默认 base=(20,10,10)。"""
    # 映射：room_id -> 场景路径
    if room_id.startswith("room_pass_") or room_id.startswith("room_hall_"):
        tscn = ROOMS_DIR / f"{room_id}.tscn"
    else:
        # room_00, room_01, ...
        tscn = ROOMS_DIR / f"{room_id}.tscn"
    if not tscn.exists():
        return (20.0, 10.0, 10.0)
    text = tscn.read_text(encoding="utf-8")
    m = re.search(r"room_volume\s*=\s*Vector3\s*\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", text)
    if m:
        return (float(m.group(1)), float(m.group(2)), float(m.group(3)))
    return (20.0, 10.0, 10.0)


def world_to_grid(px: float, py: float, xR: float, yR: float) -> tuple[int, int]:
    """
    将世界坐标和房间尺寸转换为 grid_x, grid_y。
    pivot 为底面中心：世界左 = px - xR*0.25，底 = py。
    """
    # 浮点误差处理：近零值视为 0
    if abs(px) < 1e-5:
        px = 0.0
    if abs(py) < 1e-5:
        py = 0.0
    hx = xR * 0.25  # half length in meters
    world_left = px - hx
    world_bottom = py
    gx = int(world_left // GRID_CELL_METERS)
    gy = int(world_bottom // GRID_CELL_METERS)
    return (gx, gy)


def main():
    positions = parse_archives_scene(ARCHIVES_TSCN)
    # room_01 无显式 transform，在 base_rooms 下，默认 (0,0,0)
    if "room_01" not in positions:
        positions["room_01"] = (0.0, 0.0, 0.0)

    room_info_path = ROOM_INFO_JSON
    data = json.loads(room_info_path.read_text(encoding="utf-8"))
    id_to_room = {r["id"]: r for r in data["rooms"]}

    updates: list[tuple[str, int, int, int, int]] = []

    for rid, (px, py, pz) in positions.items():
        if rid not in id_to_room:
            print(f"[skip] {rid} not in room_info.json")
            continue
        xR, yR, zR = get_room_volume(rid)
        gx, gy = world_to_grid(px, py, xR, yR)
        old_gx = id_to_room[rid].get("grid_x", 0)
        old_gy = id_to_room[rid].get("grid_y", 0)
        if old_gx != gx or old_gy != gy:
            updates.append((rid, old_gx, old_gy, gx, gy))
        id_to_room[rid]["grid_x"] = gx
        id_to_room[rid]["grid_y"] = gy

    if updates:
        print(f"更新 {len(updates)} 个房间的 grid:")
        for rid, oax, oay, nax, nay in sorted(updates, key=lambda x: x[0]):
            print(f"  {rid}: ({oax},{oay}) -> ({nax},{nay})")
        room_info_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8"
        )
        print(f"\n已写入 {room_info_path}")
    else:
        print("无需更新，grid 已与 3D 一致。")


SIZE_TO_GRID = {
    "base": (2, 1),
    "small": (1, 1),
    "tall": (2, 2),
    "small_tall": (1, 2),
    "long": (4, 1),
}


def rects_adjacent(ax1: int, ay1: int, aw: int, ah: int, bx1: int, by1: int, bw: int, bh: int) -> bool:
    """两矩形是否共边（与 RoomLayoutHelper.rects_adjacent 一致）"""
    ax2, ay2 = ax1 + aw, ay1 + ah
    bx2, by2 = bx1 + bw, by1 + bh
    if not (ax1 >= bx2 or bx1 >= ax2 or ay1 >= by2 or by1 >= ay2):
        return False  # 重叠
    if ax1 < bx2 and bx1 < ax2:
        if ay2 == by1 or by2 == ay1:
            return True
    if ay1 < by2 and by1 < ay2:
        if ax2 == bx1 or bx2 == ax1:
            return True
    return False


def verify_adjacency(data: dict, pairs: list[tuple[str, str]]) -> None:
    """验证指定房间对是否邻接"""
    id_to_r = {r["id"]: r for r in data["rooms"]}
    print("\n邻接验证:")
    for a, b in pairs:
        ra = id_to_r.get(a)
        rb = id_to_r.get(b)
        if not ra or not rb:
            print(f"  [skip] {a}-{b}: 房间不存在")
            continue
        sa = SIZE_TO_GRID.get(str(ra.get("3d_size", "base")).lower(), (1, 1))
        sb = SIZE_TO_GRID.get(str(rb.get("3d_size", "base")).lower(), (1, 1))
        adj = rects_adjacent(
            ra["grid_x"], ra["grid_y"], sa[0], sa[1],
            rb["grid_x"], rb["grid_y"], sb[0], sb[1],
        )
        status = "✓" if adj else "✗"
        print(f"  {status} {a} <-> {b}")
    print()


if __name__ == "__main__":
    main()
    data = json.loads(ROOM_INFO_JSON.read_text(encoding="utf-8"))
    verify_adjacency(data, [
        ("room_01", "room_pass_0"),  # 档案馆正厅清理后解锁F1东侧楼梯
        ("room_03", "room_pass_0"),  # 哲学文献室清理后解锁F1东侧楼梯
        ("room_03", "room_07"),      # 哲学文献室清理后解锁异常基理教习室
        ("room_00", "room_01"),      # 开篇邻接
    ])
