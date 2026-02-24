#!/usr/bin/env python3
"""
Build UI index from old-archives Godot project.
Parses .tscn files and docs/design/*.md, outputs designs/ui-index.json.
Uses only stdlib: json, re, pathlib.
"""

from __future__ import annotations

import json
import re
from pathlib import Path


def _color_to_hex(color_match: re.Match) -> str:
    """Convert Godot Color(r,g,b,a) to #RRGGBBAA hex."""
    groups = color_match.groups()
    if len(groups) < 4:
        return "#ffffffff"
    r, g, b = int(float(groups[0]) * 255), int(float(groups[1]) * 255), int(float(groups[2]) * 255)
    a = float(groups[3]) if len(groups) > 3 else 1.0
    a_int = int(a * 255)
    return f"#{r:02x}{g:02x}{b:02x}{a_int:02x}"


def parse_tscn(path: Path) -> list[dict]:
    """Parse a .tscn file and return list of elements (Label/Button with text, colors, layout)."""
    text = path.read_text(encoding="utf-8")
    elements: list[dict] = []

    # Match node blocks: [node name="X" type="Label" parent="path"] ... text = "..." ...
    node_pattern = re.compile(
        r'\[node\s+name="([^"]+)"\s+type="(Label|Button)"\s+parent="([^"]*)"[^\]]*\]'
        r"((?:(?!\[node\s)[\s\S])*?)"
        r"(?=\[node\s|\Z)",
        re.MULTILINE,
    )

    color_pattern = re.compile(r"Color\s*\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)")
    font_color_pattern = re.compile(
        r"theme_override_colors/font_color\s*=\s*Color\s*\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)"
    )
    font_size_pattern = re.compile(r"theme_override_font_sizes/font_size\s*=\s*(\d+)")
    text_pattern = re.compile(r'text\s*=\s*"((?:[^"\\]|\\.)*)"', re.DOTALL)

    for m in node_pattern.finditer(text):
        name, ntype, parent = m.group(1), m.group(2), m.group(3)
        block = m.group(4) or ""

        text_val = text_pattern.search(block)
        if not text_val and ntype != "Label":
            text_val = text_pattern.search(block)
        content = text_val.group(1).replace("\\n", "\n") if text_val else ""

        fill_match = font_color_pattern.search(block)
        if fill_match:
            fill = _color_to_hex(fill_match)
        else:
            col = color_pattern.search(block)
            fill = _color_to_hex(col) if col else "#ffffffff"

        font_size_match = font_size_pattern.search(block)
        font_size = int(font_size_match.group(1)) if font_size_match else None

        path_parts = [p for p in parent.split("/") if p]
        path_parts.append(name)
        rel_path = "/".join(path_parts)

        el = {
            "path": rel_path,
            "type": ntype,
            "text": content,
            "fill": fill,
        }
        if font_size is not None:
            el["fontSize"] = font_size
        elements.append(el)

    return elements


def parse_tscn_styles(path: Path) -> dict:
    """Extract StyleBoxFlat bg_color and corner_radius from .tscn."""
    text = path.read_text(encoding="utf-8")
    result: dict = {}
    color_pattern = re.compile(r"Color\s*\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)")
    # StyleBoxFlat panel
    flat = re.search(
        r"\[sub_resource\s+type=\"StyleBoxFlat\"[^\]]*\]\s*(.*?)(?=\[|\Z)",
        text,
        re.DOTALL,
    )
    if flat:
        block = flat.group(1)
        bg = re.search(r"bg_color\s*=\s*Color\s*\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", block)
        if bg:
            r, g, b, a = float(bg.group(1)), float(bg.group(2)), float(bg.group(3)), float(bg.group(4))
            result["bgColor"] = f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}{int(a*255):02x}"
        cr = re.search(r"corner_radius(?:_bottom_right)?\s*=\s*(\d+)", block)
        if cr:
            result["cornerRadius"] = int(cr.group(1))

    # offset_bottom for height
    h = re.search(r"offset_bottom\s*=\s*([\d.]+)", text)
    if h:
        result["height"] = int(float(h.group(1)))
    return result


def extract_layout_from_docs(docs_dir: Path) -> dict:
    """Extract layout constants from docs/design/*.md."""
    layout: dict = {}
    overview = docs_dir / "06-ui-main-overview.md"
    if overview.exists():
        text = overview.read_text(encoding="utf-8")
        # Color(0.12, 0.12, 0.18, 0.92)
        m = re.search(r"bg_color\s*=\s*Color\s*\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", text)
        if m:
            r, g, b, a = float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4))
            layout["topbarBgColor"] = f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}{int(a*255):02x}"
        sep = re.search(r"separation\s+(\d+)", text)
        if sep:
            layout["hboxSeparation"] = int(sep.group(1))
        cr = re.search(r"圆角\s*(\d+)", text)
        if cr:
            layout["cornerRadius"] = int(cr.group(1))
    return layout


def main() -> None:
    root = Path(__file__).resolve().parent.parent.parent
    designs_dir = root / "designs"
    scenes_ui = root / "scenes" / "ui"
    docs_design = root / "docs" / "design"

    designs_dir.mkdir(parents=True, exist_ok=True)

    components: list[dict] = []
    doc_layout = extract_layout_from_docs(docs_design) if docs_design.exists() else {}

    # 1. ui_main.tscn - TopBar
    ui_main = scenes_ui / "ui_main.tscn"
    if ui_main.exists():
        elements = parse_tscn(ui_main)
        styles = parse_tscn_styles(ui_main)
        # Filter to TopBar/Content/HBox subtree (exclude TimePanel, ShelterErosionPanel instance children)
        topbar_elements = [
            e
            for e in elements
            if not any(
                p in e["path"]
                for p in ("TimePanel", "ShelterErosionPanel", "SpacerLeft", "SpacerRight", "VSep")
            )
        ]
        components.append(
            {
                "id": "ui_main_topbar",
                "name": "主 UI TopBar",
                "sources": ["scenes/ui/ui_main.tscn", "docs/design/06-ui-main-overview.md"],
                "elements": topbar_elements,
                "layout": {
                    "orientation": "horizontal",
                    "height": styles.get("height", 48),
                    "bgColor": styles.get("bgColor", doc_layout.get("topbarBgColor", "#1e1e2e")),
                    "cornerRadius": styles.get("cornerRadius", doc_layout.get("cornerRadius", 4)),
                    "gap": doc_layout.get("hboxSeparation", 32),
                },
            }
        )

    # 2. time_panel.tscn
    time_panel = scenes_ui / "time_panel.tscn"
    if time_panel.exists():
        elements = parse_tscn(time_panel)
        components.append(
            {
                "id": "time_panel",
                "name": "时间面板 TimePanel",
                "sources": ["scenes/ui/time_panel.tscn", "docs/design/04-time-system.md"],
                "elements": elements,
                "layout": {"orientation": "horizontal", "height": 28, "gap": 12},
            }
        )

    # 3. shelter_erosion_panel.tscn
    shelter_panel = scenes_ui / "shelter_erosion_panel.tscn"
    if shelter_panel.exists():
        elements = parse_tscn(shelter_panel)
        components.append(
            {
                "id": "shelter_erosion_panel",
                "name": "庇护/侵蚀面板 ShelterErosionPanel",
                "sources": ["scenes/ui/shelter_erosion_panel.tscn", "docs/design/05-shelter-erosion-ui.md"],
                "elements": elements,
                "layout": {"orientation": "horizontal", "minWidth": 280, "gap": 12},
            }
        )

    index = {
        "version": "1.0",
        "project": "old-archives-sp",
        "components": components,
    }

    out_path = designs_dir / "ui-index.json"
    out_path.write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {out_path} with {len(components)} components.")


if __name__ == "__main__":
    main()
