#!/usr/bin/env python3
"""
虚拟测试（不写回任何项目资源、不生成场景）：

在现有 room_info.json 的 layout_cells 并集之外，沿「与已占用格相邻的空格」
随机贴靠放置若干虚拟房间；尺寸从与游戏一致的 SIZE_TO_GRID 中抽取，
且至少各包含一次 base / small / tall / small_tall / long；再随机追加数个房间。

对每个试次用与运行时相同的规则（两房格集间存在曼哈顿距离为 1 的一对格即相邻）
建图，从 room_00 做 BFS，断言「原 36 间 + 全部虚拟房」同一连通分量。

用法（仓库根目录）:
  python tools/scripts/virtual_random_rooms_connectivity_test.py
  python tools/scripts/virtual_random_rooms_connectivity_test.py --trials 50 --seed 42
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROOM_INFO = ROOT / "datas" / "room_info.json"

SIZE_TO_GRID: dict[str, tuple[int, int]] = {
    "base": (2, 1),
    "small": (1, 1),
    "tall": (2, 2),
    "small_tall": (1, 2),
    "long": (4, 1),
}


def manhattan_adjacent(a: tuple[int, int], b: tuple[int, int]) -> bool:
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1


def rooms_adjacent(cells_a: set[tuple[int, int]], cells_b: set[tuple[int, int]]) -> bool:
    for x in cells_a:
        for y in cells_b:
            if manhattan_adjacent(x, y):
                return True
    return False


def load_archive_id_cells() -> dict[str, set[tuple[int, int]]]:
    data = json.loads(ROOM_INFO.read_text(encoding="utf-8"))
    rooms: list[dict] = data.get("rooms", [])
    id_cells: dict[str, set[tuple[int, int]]] = {}
    for r in rooms:
        if "grid_x" not in r or "grid_y" not in r:
            continue
        rid = str(r.get("id", ""))
        if not rid:
            continue
        lc = r.get("layout_cells")
        if not isinstance(lc, list) or not lc:
            raise SystemExit(f"房间 {rid} 缺少 layout_cells，无法加载虚拟测试。")
        cells: set[tuple[int, int]] = set()
        for pair in lc:
            if isinstance(pair, (list, tuple)) and len(pair) >= 2:
                cells.add((int(pair[0]), int(pair[1])))
        id_cells[rid] = cells
    if "room_00" not in id_cells:
        raise SystemExit("缺少 room_00")
    return id_cells


def collect_candidates(
    union: set[tuple[int, int]], w: int, h: int, pad: int
) -> list[set[tuple[int, int]]]:
    if not union:
        return []
    min_x = min(c[0] for c in union) - pad
    max_x = max(c[0] for c in union) + pad
    min_y = min(c[1] for c in union) - pad
    max_y = max(c[1] for c in union) + pad
    out: list[set[tuple[int, int]]] = []
    for gx in range(min_x, max_x + 1):
        for gy in range(min_y, max_y + 1):
            cells = {(gx + dx, gy + dy) for dx in range(w) for dy in range(h)}
            if cells & union:
                continue
            touches = False
            for c in cells:
                for nb in (
                    (c[0] + 1, c[1]),
                    (c[0] - 1, c[1]),
                    (c[0], c[1] + 1),
                    (c[0], c[1] - 1),
                ):
                    if nb in union:
                        touches = True
                        break
                if touches:
                    break
            if touches:
                out.append(cells)
    return out


def try_place(
    union: set[tuple[int, int]], w: int, h: int, rng: random.Random
) -> set[tuple[int, int]] | None:
    pad = max(w, h) + 8
    candidates = collect_candidates(union, w, h, pad)
    if not candidates:
        pad += 12
        candidates = collect_candidates(union, w, h, pad)
    if not candidates:
        return None
    return rng.choice(candidates)


def bfs_all_reachable(
    id_cells: dict[str, set[tuple[int, int]]], start: str = "room_00"
) -> tuple[set[str], list[str]]:
    ids = list(id_cells.keys())
    neighbors: dict[str, list[str]] = {i: [] for i in ids}
    for i, a in enumerate(ids):
        for b in ids[i + 1 :]:
            if rooms_adjacent(id_cells[a], id_cells[b]):
                neighbors[a].append(b)
                neighbors[b].append(a)
    seen: set[str] = {start}
    q: deque[str] = deque([start])
    while q:
        u = q.popleft()
        for v in neighbors.get(u, []):
            if v not in seen:
                seen.add(v)
                q.append(v)
    missing = [rid for rid in ids if rid not in seen]
    return seen, missing


def one_trial(
    base_id_cells: dict[str, set[tuple[int, int]]],
    rng: random.Random,
    extra_random_rooms: int,
) -> tuple[bool, str]:
    """返回 (是否成功, 说明文本)。"""
    id_cells = {k: set(v) for k, v in base_id_cells.items()}
    union: set[tuple[int, int]] = set()
    for s in id_cells.values():
        union |= s

    sizes_order = list(SIZE_TO_GRID.keys())
    rng.shuffle(sizes_order)
    virtual_meta: list[tuple[str, str, int, int]] = []
    vi = 0

    for size_name in sizes_order:
        w, h = SIZE_TO_GRID[size_name]
        cells = try_place(union, w, h, rng)
        if cells is None:
            return False, f"无法在边界贴靠放置尺寸 {size_name} ({w}×{h})"
        vid = f"__virtual_{vi}"
        vi += 1
        id_cells[vid] = cells
        union |= cells
        virtual_meta.append((vid, size_name, w, h))

    for _ in range(extra_random_rooms):
        size_name = rng.choice(list(SIZE_TO_GRID.keys()))
        w, h = SIZE_TO_GRID[size_name]
        cells = try_place(union, w, h, rng)
        if cells is None:
            return False, f"额外随机房无法放置（{size_name} {w}×{h}）"
        vid = f"__virtual_{vi}"
        vi += 1
        id_cells[vid] = cells
        union |= cells
        virtual_meta.append((vid, size_name, w, h))

    _, missing = bfs_all_reachable(id_cells, "room_00")
    if missing:
        return False, "BFS 未覆盖: " + ", ".join(sorted(missing)[:12]) + (
            "..." if len(missing) > 12 else ""
        )

    lines = [
        f"虚拟房共 {len(virtual_meta)} 间（含五种尺寸各至少 1 间 + {extra_random_rooms} 间随机）。",
        "样例（前 8 间）:",
    ]
    for row in virtual_meta[:8]:
        lines.append(f"  {row[0]}  {row[1]}  {row[2]}×{row[3]}  格数={row[2]*row[3]}")
    return True, "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="虚拟随机贴边房间 + BFS 连通性测试")
    ap.add_argument("--trials", type=int, default=30, help="随机试次数量")
    ap.add_argument("--seed", type=int, default=None, help="随机种子（默认每次用系统熵）")
    ap.add_argument(
        "--extra",
        type=int,
        default=6,
        help="在五种必选尺寸之外再随机贴靠的房间数（默认 6）",
    )
    ap.add_argument(
        "--quiet",
        action="store_true",
        help="仅输出失败信息与最终总结（不逐次打印样例）",
    )
    args = ap.parse_args()

    base = load_archive_id_cells()
    n_archive = len(base)
    print(
        f"已加载档案馆房间 {n_archive} 间；算法：layout_cells 两两曼哈顿 1 则相邻；起点 room_00。"
    )

    failures = 0
    for t in range(args.trials):
        seed = args.seed if args.seed is not None else random.randrange(1 << 30)
        rng = random.Random(seed ^ t * 0x9E3779B9)
        ok, msg = one_trial(base, rng, args.extra)
        if not ok:
            failures += 1
            print(f"[试次 {t+1}/{args.trials}] 失败 seed^={seed} t: {msg}", file=sys.stderr)
        elif not args.quiet:
            print(f"[试次 {t+1}/{args.trials}] 通过 (内部种子 {seed}, t={t})")
            print(msg)

    if failures:
        print(
            f"\n总结：{args.trials - failures}/{args.trials} 通过，{failures} 次失败。",
            file=sys.stderr,
        )
        return 1
    print(f"\n总结：{args.trials}/{args.trials} 次试次全部通过。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
