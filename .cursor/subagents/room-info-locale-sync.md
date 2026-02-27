# room_info 本地化同步子代理

当用户说「我调整了 roominfo」「我改了 room_info」「roominfo 更新了」或类似表述时，**必须**执行本工作流，将 room_info.json 中的 room_name、pre_clean_text、desc 同步至 translations.csv 并生成英文翻译。

## 一、相关文件

| 文件 | 说明 |
|------|------|
| `datas/room_info.json` | 权威数据源，保持中文编辑 |
| `translations/translations.csv` | 翻译表，需合并 room 相关键 |
| `docs/design/locale/01-localization.md` | 本地化设计文档 |
| `docs/design/1-editor/02-room-info-and-json-sync.md` | room_info 与 JSON 同步规范 |

## 二、Key 命名约定

以 room id 为前缀（如 ROOM_001）：

| 字段 | Key 示例 | 说明 |
|------|----------|------|
| room_name | ROOM_001_NAME | 房间名称 |
| pre_clean_text | ROOM_001_PRE_CLEAN | 清理前文本（数组用 \n 拼接） |
| desc | ROOM_001_DESC | 房间描述（数组用 \n 拼接） |

room_type 由 room_type_id + RoomInfo.get_room_type_name() 处理，已有 ROOM_TYPE_* 键，无需同步。

## 三、同步工作流

1. **解析** `datas/room_info.json`，遍历 `rooms` 数组。

2. **对每个 room**：
   - 用 `id`（如 ROOM_001）生成键：`ROOM_001_NAME`、`ROOM_001_PRE_CLEAN`、`ROOM_001_DESC`
   - `pre_clean_text` / `desc` 若为数组，用 `\n` 拼接为单行字符串
   - **zh_CN**：直接使用 JSON 中的中文
   - **en**：将 zh_CN 内容翻译为英文（由 AI 在同一轮对话中完成）

3. **合并到** `translations/translations.csv`：
   - 读取现有 CSV，保留所有非 ROOM_XXX_* 键
   - 新增或更新 ROOM_XXX_NAME、ROOM_XXX_PRE_CLEAN、ROOM_XXX_DESC
   - 含逗号、换行、双引号的字段需按 CSV 规范转义

4. **输出**：简要说明已同步房间数量及更新的键。

## 四、翻译要求

- desc 常为多行叙事，翻译时保持段落结构和语气
- 专有名词（人名、地名等）可保留或音译，保持一致性
- 若某条无法翻译，en 列可暂填 `[TODO]` 供后续补齐

## 五、工具脚本（可选）

`scripts/tools/room_info_locale_sync.py` 可自动解析 room_info.json、合并到 translations.csv。若环境中 Python 可用，可执行该脚本加速同步；否则按步骤 1–4 手动操作。

## 六、委托执行

当执行本工作流时，应直接按上述步骤操作，或调用 mcp_task（subagent_type=generalPurpose）委托执行，prompt 中附上本工作流及 `datas/room_info.json` 路径。
