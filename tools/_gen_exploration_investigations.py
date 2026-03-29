# One-off generator; run: python tools/_gen_exploration_investigations.py
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGIONS = [
    ("old_archives", "旧日档案馆"),
    ("white_cliff", "白崖镇"),
    ("durkin_mine", "杜尔金矿区"),
    ("mandos_industrial", "曼多斯工业区"),
    ("bolero_port", "波莱罗港"),
    ("saint_river_afv", "圣河亚弗"),
    ("andal_town", "安达尔镇"),
    ("korloh_sea", "科尔洛海"),
    ("bluewood_transit", "蓝木跃迁线"),
    ("grey_town", "格雷镇"),
    ("ural_mountain", "乌拉尔山"),
    ("new_barguzin", "新巴尔古津"),
    ("morku_industrial", "莫尔库工业区"),
    ("mason_port", "石匠港"),
    ("west_202_port", "西202港"),
    ("korborko", "科尔博柯"),
]


def body(name: str, sn: int) -> str:
    return (
        f"【占位-调查点】地区：{name} · 调查点序号 {sn}\n"
        "【占位】此处为事件背景/现场情况描述（行 2）。\n"
        "【占位】此处为可交互线索或风险说明（行 3）。\n"
        "【占位】请选择下方一项行动；「稍后处理」仅关闭界面不结算。"
    )


def main() -> None:
    sites_by_region: dict = {}
    for rid, name in REGIONS:
        sites = []
        for si in (1, 2):
            sid = f"inv_{rid}_{si}"
            opts = []
            for oi in (1, 2):
                cost = {"info": 5} if oi == 1 else {}
                reward = {"cognition": 10} if oi == 2 else {}
                opts.append(
                    {
                        "id": f"opt_{sid}_{oi}",
                        "label_zh": f"测试选项{oi}",
                        "hint_zh": f"【占位】测试选项{oi}：消耗/收益见结构化字段（当前可为空）。",
                        "cost": cost,
                        "reward": reward,
                    }
                )
            sites.append(
                {
                    "id": sid,
                    "title_zh": f"测试调查点{si}",
                    "body_zh": body(name, si),
                    "image": "",
                    "options": opts,
                }
            )
        sites_by_region[rid] = sites
    out = {
        "schema_version": 1,
        "description": "探索调查点静态配置（测试占位命名）；每区 2 点、每点 2 选项。",
        "sites_by_region": sites_by_region,
    }
    path = ROOT / "datas" / "exploration_investigations.json"
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Wrote", path, "regions", len(sites_by_region))


if __name__ == "__main__":
    main()
