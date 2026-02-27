#!/usr/bin/env python3
"""从 room_info.json 提取 room_name、pre_clean_text、desc，生成 translations.csv 的 room 键。"""
import json
import csv
import os

ROOM_INFO_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "datas", "room_info.json")
TRANSLATIONS_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "translations", "translations.csv")
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "translations", "translations_new.csv")


def _join_field(v) -> str:
    if v is None:
        return ""
    if isinstance(v, list):
        return "\n".join(str(x) for x in v)
    return str(v)


def _csv_escape(s: str) -> str:
    if not s:
        return '""'
    if '"' in s or "," in s or "\n" in s or "\r" in s:
        return '"' + s.replace('"', '""') + '"'
    return s


# 中文 → 英文翻译（可后续人工校对）
TRANSLATIONS = {
    "档案馆正厅": "Archive Hall",
    "档案馆门卫室": "Archive Gatehouse",
    "档案馆核心": "Archive Core",
    "制药研究室": "Pharmaceutical Research Lab",
    "哲学文献室": "Philosophy Archives",
    "书记员房间": "Scribe's Room",
    "终端操作台": "Terminal Console",
    "刊物档案室": "Periodical Archives",
    "格温的临时事务所": "Gwen's Temporary Office",
    "案情陈列室": "Case Exhibits Room",
    "副楼房间F101": "Annex Room F101",
    "副楼房间F102": "Annex Room F102",
    "副楼房间F201": "Annex Room F201",
    "副楼房间F202": "Annex Room F202",
    "副楼房间F301": "Annex Room F301",
    "副楼房间F302": "Annex Room F302",
    "副楼房间F401": "Annex Room F401",
    "副楼房间F402": "Annex Room F402",
    "副楼房间F501": "Annex Room F501",
    "默认清理前文本": "Default pre-clean text",
    "原本空闲的房间，也曾多用于客房。": "Originally vacant, often used as guest rooms.",
    "探寻者-维瑟建立这座档案馆，并以此中智慧破译智者罗曼所留下的道标，": "The Seeker-Visser founded this archive and deciphered the beacons left by the Sage Roman with its wisdom.",
    "为此他不惜驯服时间、迈入永恒。": "For this he tamed time and stepped into eternity.",
    "「 只要你仍在档案馆内，便无需理会时间之残忍。": "\"As long as you remain within the archive, you need not heed time's cruelty.",
    "在永恒的时间中，并没有任何路径会被阻断。 」": "In eternal time, no path shall be blocked.\"",
    "在档案馆作为私有庄园的年代，这里只是一个管家的居所，": "When the archive was a private estate, this was merely the steward's quarters.",
    "第八任管理员特伦德宣布档案馆对外开放，将此处改为门卫室查问外来者。": "The eighth administrator Trend declared the archive open to the public and converted it into a gatehouse to screen visitors.",
    "他决心让档案馆中的知识和信息能带给这个离析的世界一些改变。他做到了，但这也是他晚年悲剧的原因。\"之一？\"": "He resolved to bring change to this fragmented world through the archive's knowledge. He succeeded—but that also became the cause of his late-life tragedy. \"One of them?\"",
    "档案馆的心脏，能够通过消耗计算因子为档案馆带来文明的庇佑，": "The heart of the archive, able to bring civilization's blessing by consuming computation factor.",
    "阻隔来自暴君—莱卡昂的神秘侵蚀。": "Blocking the mystery erosion from the Tyrant Lycaon.",
    "小伊凡中尉精通制药，他的药剂学术超出时代、科技和现实的限制，": "Lieutenant Ivan Jr. mastered pharmacy; his pharmaceutical knowledge transcended era, technology, and reality.",
    "他在地下建立了一个隐匿的医院。": "He built a hidden hospital underground.",
    "以哲学资料、文献为主的档案室，空气中仍然弥漫着厚重的烟草味，": "An archive of philosophy materials and documents; the air still carries the scent of tobacco.",
    "曾有东方的年轻管理员在此研习晦涩的哲思。": "A young administrator from the East once studied obscure philosophy here.",
    "这个房间曾经由白文先生的书记员-弗耶所使用，": "This room was once used by Mr. Baiwen's scribe, Fuye.",
    "他负责辅助整理、收纳和誊写关于档案馆进出典籍的资料。": "He assisted in organizing, cataloging, and transcribing records of the archive's books.",
    "苍白巨像的操作台终端，": "The terminal console of the Pale Colossus.",
    "虽然仅能使用一小部分苍白巨像的能力。": "Though it can only harness a fraction of the Pale Colossus's power.",
    "阿德利亚依靠其信息学、传播学知识重建了刊物档案室，": "Adelia rebuilt the periodical archive with her knowledge of informatics and communications.",
    "整理收纳了世界各地的录音录像出版物。": "Organizing and cataloging audiovisual publications from around the world.",
    "格温·别利琴科组建的调查员团队短暂以此为据点。作为解决了科尔博柯事件的调查员，格温最终也加入到对抗莱卡昂的战争中": "Gwen Belychenko's investigator team briefly used this as their base. As the investigator who resolved the Kolboko incident, Gwen eventually joined the war against Lycaon.",
    "旧的案件档案堆放其中，": "Old case files are stacked here.",
    "一个巨型的线索板满是贴纸。": "A giant clue board covered in sticky notes.",
}


def translate_zh_to_en(zh: str) -> str:
    if not zh or not zh.strip():
        return ""
    return TRANSLATIONS.get(zh.strip(), zh)


def translate_desc(zh_lines: str) -> str:
    lines = zh_lines.split("\n")
    en_lines = [translate_zh_to_en(line) for line in lines]
    return "\n".join(en_lines)


def main():
    with open(ROOM_INFO_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    rooms = data.get("rooms", [])
    room_keys = set()
    room_rows = []
    for r in rooms:
        rid = r.get("id", "")
        if not rid or rid in room_keys:
            continue
        room_keys.add(rid)
        name_zh = str(r.get("room_name", ""))
        pre_zh = _join_field(r.get("pre_clean_text", ""))
        desc_zh = _join_field(r.get("desc", ""))
        name_en = translate_zh_to_en(name_zh)
        pre_en = translate_zh_to_en(pre_zh) if pre_zh else ""
        desc_en = translate_desc(desc_zh) if desc_zh else ""
        room_rows.append((f"{rid}_NAME", name_en or name_zh, name_zh))
        room_rows.append((f"{rid}_PRE_CLEAN", pre_en or pre_zh, pre_zh or "默认清理前文本"))
        room_rows.append((f"{rid}_DESC", desc_en or desc_zh, desc_zh))
    # 读取现有 CSV
    existing = []
    with open(TRANSLATIONS_PATH, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            existing.append(row)
    new_keys = {r[0] for r in room_rows}
    merged = []
    for row in existing:
        if row["keys"] not in new_keys:
            merged.append(row)
    for key, en, zh in room_rows:
        merged.append({"keys": key, "en": en, "zh_CN": zh})
    with open(TRANSLATIONS_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["keys", "en", "zh_CN"])
        writer.writeheader()
        writer.writerows(merged)
    print(f"Synced {len(rooms)} rooms, added {len(room_rows)} translation keys.")


if __name__ == "__main__":
    main()
