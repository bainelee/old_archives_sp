import json
from pathlib import Path
ROOT = Path('.').resolve()
GRID = 5.25
scene_lines = (ROOT / "scenes/game/archives_base_0.tscn").read_text(encoding="utf-8").splitlines()
positions = {}
cur = None
for ln in scene_lines:
    if ln.startswith('[node name="'):
        name = ln.split('"')[1]
        if name.startswith("room_") and name not in ("room_out_block_down","room_out_block_up","room_out_block_left","room_out_block_right"):
            cur = name
        else:
            cur = None
        continue
    if cur and "transform = Transform3D(" in ln:
        inside = ln.split("Transform3D(", 1)[1].rsplit(")", 1)[0]
        parts = [p.strip() for p in inside.split(",")]
        if len(parts) >= 12:
            positions[cur] = (float(parts[9]), float(parts[10]))
        cur = None
if "room_01" not in positions:
    positions["room_01"] = (0.0, 0.0)
volumes = {}
for p in (ROOT / "scenes/rooms/archives_rooms").glob("room_*.tscn"):
    v = (20.0, 10.0)
    for ln in p.read_text(encoding="utf-8").splitlines():
        if "room_volume = Vector3(" in ln:
            inside = ln.split("Vector3(", 1)[1].rsplit(")", 1)[0]
            ps = [x.strip() for x in inside.split(",")]
            if len(ps) >= 2:
                v = (float(ps[0]), float(ps[1]))
            break
    volumes[p.stem] = v
info = json.loads((ROOT / "datas/room_info.json").read_text(encoding="utf-8"))
size = {"base": (2, 1), "small": (1, 1), "tall": (2, 2), "small_tall": (1, 2), "long": (4, 1)}
new_rooms = []
for r in info["rooms"]:
    rid = r["id"]
    if rid not in positions:
        continue
    px, py = positions[rid]
    xR, _ = volumes.get(rid, (20.0, 10.0))
    world_left = px - xR * 0.25
    gx, gy = round(world_left / GRID), round(py / GRID)
    s = str(r.get("3d_size", r.get("size_3d", "base"))).lower()
    w, h = size.get(s, (1, 1))
    new_rooms.append({"id": rid, "gx": int(gx), "gy": int(gy), "w": w, "h": h})

def adj(a, b):
    ax1, ay1, aw, ah = a["gx"], a["gy"], a["w"], a["h"]
    bx1, by1, bw, bh = b["gx"], b["gy"], b["w"], b["h"]
    ax2, ay2 = ax1 + aw, ay1 + ah
    bx2, by2 = bx1 + bw, by1 + bh
    if not (ax1 >= bx2 or bx1 >= ax2 or ay1 >= by2 or by1 >= ay2):
        return False
    if ax1 < bx2 and bx1 < ax2 and (ay2 == by1 or by2 == ay1):
        return True
    if ay1 < by2 and by1 < ay2 and (ax2 == bx1 or bx2 == ax1):
        return True
    return False
ids = [r["id"] for r in new_rooms]
g = {i: set() for i in ids}
m = {r["id"]: r for r in new_rooms}
for i, aid in enumerate(ids):
    a = m[aid]
    for bid in ids[i+1:]:
        b = m[bid]
        if adj(a, b):
            g[aid].add(bid); g[bid].add(aid)
seen, q = set(["room_00"]), ["room_00"]
while q:
    n = q.pop(0)
    for nb in g[n]:
        if nb not in seen:
            seen.add(nb); q.append(nb)
print("reachable_from_room00", len(seen), "/", len(ids))
un = set(ids); comps = []
while un:
    s = next(iter(un)); comp = {s}; qq = [s]; un.remove(s)
    while qq:
        n = qq.pop(0)
        for nb in g[n]:
            if nb in un:
                un.remove(nb); comp.add(nb); qq.append(nb)
    comps.append(comp)
print("components", len(comps), "sizes", sorted([len(c) for c in comps], reverse=True))
for rid in ["room_pass_1","room_pass_2","room_pass_3","room_06","room_09","room_10","room_12","room_00","room_01"]:
    if rid in m:
        print(rid, "grid", m[rid]["gx"], m[rid]["gy"], "neighbors", sorted(g[rid]))
