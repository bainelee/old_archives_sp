# 房间类型定义

本文件定义档案馆房间类型的中英文对照，供 `archive_rooms_info`、`room_info.json`、本地化及玩法配置引用。

---

## 房间类型对照表

| 中文 | English |
|------|---------|
| 核心 | Core |
| 资料库 | Archive |
| 图书室 | Library |
| 机房 | Server Room |
| 教学室 | Classroom |
| 实验室 | Lab |
| 推理室 | Case Room |
| 事务所遗址 | Agency Ruins |
| 通道 | Corridor |
| 庭院 | Courtyard |
| 放映厅 | Screening Room |
| 教堂 | Chapel |
| 冥想室 | Meditation Room |
| 遗迹 | Ruins |
| 奇观 | Wonder |
| 医疗室 | Infirmary |
| 疗养室 | Recovery Room |
| 宿舍 | Dormitory |
| 检修室 | Maintenance Room |

---

## 代码实现状态

`RoomInfo.RoomType` 与 `room_info_loader._room_type_from_string` 中已实现的类型：

| 中文 | RoomType 枚举 | room_info.json 可填值 |
|------|---------------|------------------------|
| 核心 | ARCHIVE_CORE | 核心、core |
| 资料库 | ARCHIVE | 资料库、archive |
| 图书室 | LIBRARY | 图书室、library |
| 机房 | LAB | 机房、lab、server room |
| 教学室 | CLASSROOM | 教学室、classroom |
| 实验室 | SERVER_ROOM | 实验室、server_room |
| 推理室 | REASONING | 推理室、reasoning |
| 事务所遗址 | OFFICE_SITE | 事务所遗址、office_site |
| 宿舍 | DORMITORY | 宿舍、dormitory |
| 检修室 | MAINTENANCE | 检修室、maintenance |
| 通道 | CORRIDOR | 通道、corridor |
| 庭院 | COURTYARD | 庭院、courtyard |
| 放映厅、教堂等设计预留 | EMPTY_ROOM | 上表未列之类型 |

新增房间类型时需同时更新：`room_info.gd` 枚举、`get_room_type_name`、`room_info_loader`、`translations.csv` 的 `ROOM_TYPE_XXX`、本表。

---

## 使用说明

- **中文**：用于 `archive_rooms_info.md`、`room_info.json` 及设计文档中的「房间类型」列。
- **English**：用于本地化 key（如 `ROOM_TYPE_XXX`）、代码常量及英文 UI。
- 新增房间类型时需同步更新本表及相关配置。

---

## 相关文档

- [archives_rooms 房间信息](./01-archive_rooms_info.md)
- [房间尺寸与设计规范](./02-room-dimensions-and-specs.md)
