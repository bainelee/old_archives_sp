# 07 - room_info 本地化同步流程（固定流程）

## 目标

当 `datas/room_info.json` 的房间名称/描述更新后，稳定同步到 `translations/translations.csv`，保证运行时 `tr("{id}_NAME") / tr("{id}_PRE_CLEAN") / tr("{id}_DESC")` 可用。

---

## 同步脚本

- 脚本：`scripts/tools/room_info_locale_sync.py`
- 数据源：`datas/room_info.json`
- 输出：直接覆盖 `translations/translations.csv`
- 键规则：
  - `{id}_NAME`
  - `{id}_PRE_CLEAN`
  - `{id}_DESC`

---

## 执行步骤

1. 更新 `datas/room_info.json`（仅改文案/房间 ID）。
2. 运行脚本生成/覆盖房间文案键。
3. 打开 `translations/translations.csv`，人工抽检新增或改动项。
4. 启动游戏，抽查房间详情面板中中英切换显示。

---

## 回归清单

- [ ] 每个房间存在 3 个键：`_NAME/_PRE_CLEAN/_DESC`
- [ ] key 前缀与 `room_info.json` 的 `id` 完全一致（大小写一致）
- [ ] `room_detail_panel_figma` 中名称和描述均由本地化读取
- [ ] 缺失 key 时可回退到 `room_info.json` 原文，不出现空文本
- [ ] 多行 `desc`（数组）在 CSV 中换行保持正确

---

## 注意事项

- `room_info.json` 保持中文原文，便于策划维护。
- 英文翻译可先脚本生成，再人工润色；不要手动改动 key 命名规则。
- 若新增房间 ID，必须先补 `translations.csv` 再提测，避免 UI 回退文案混杂。
