# 旧日档案馆 (Old Archives)

基于 Godot 4.6 引擎开发的 2D 基地建设、模拟经营、资源管理类游戏，视角类似《缺氧》《司辰之书》。

## 游戏介绍

你成为了旧日档案馆的管理员，依靠这座档案馆提供的「文明的庇佑」以阻隔来自暴君—莱卡昂的神秘侵蚀。

- 招募研究员和调查员，解锁档案馆的房间、建设更多房间来获取四种因子和更多信息
- 通过调查员外出调查，破解谜题和案件以获得真相
- 抵抗莱卡昂的暗影，最终引导革命以推翻莱卡昂的统治

## 玩法简介

玩家需要在一座废弃的档案馆中，派遣人员清理房间，将原本的房间建设为不同功能的区域：

- **研究区**
- **造物区**
- **事务所区**
- **生活区**

建设后的房间根据类型不同会产生不同的资源。四种因子（认知、计算、意志、权限）对应食物、燃料、素材、建材。

名为莱卡昂的上位者持续对整个世界造成神秘侵蚀。档案馆的核心能够通过消耗【计算因子】为档案馆带来庇护。玩家需要不断强化核心，让核心能够提供更强的庇护、覆盖更大的范围。

## 技术栈

- **引擎**：Godot 4.6
- **物理引擎**：Jolt Physics
- **渲染**：Forward Plus
- **本地化**：zh_CN（默认）、en

## 项目结构

```
old-archives-sp/
├── project.godot           # 项目配置
├── icon.svg                # 项目图标
├── README.md               # 本文件
├── scenes/                 # 场景
│   ├── editor/             # 2D 地图编辑器（单独运行）
│   ├── game/               # 游戏主场景、档案馆底板
│   ├── ui/                 # 主菜单、主 UI、时间/庇护/清理等面板
│   ├── rooms/              # 档案馆房间（3D）、预设框架
│   └── actors/             # 3D 元件与道具
├── scripts/                # 脚本
│   ├── editor/             # 地图编辑器（map_editor、room_info、底板/房间编辑）
│   ├── game/               # 游戏主逻辑（game_main、保存、清理、建设、庇护等）
│   ├── core/               # 核心系统（时间、侵蚀、数值、存档、本地化）
│   ├── ui/                 # UI 脚本
│   ├── rooms/              # 房间逻辑（网格、高亮、标牌）
│   ├── actors/             # 3D 元件逻辑
│   └── tools/              # 工具脚本（材质导入、本地化同步）
├── datas/                  # 数据文件（.gdignore，运行时加载）
│   ├── game_values.json    # 游戏数值（因子、庇护、清理、建设、产出等）
│   ├── game_base.json      # 新游戏初始资源、人员、时间
│   ├── room_info.json      # 3D 档案馆房间信息表
│   ├── room_info_legacy.json # 2D 地图编辑器模板库
│   └── actor_table.json   # 3D 元件表
├── assets/                 # 美术资源
│   ├── icons/              # 图标
│   ├── materials/          # 材质
│   ├── meshes/             # GLB 模型、贴图
│   ├── misc/               # 杂项图片
│   ├── sprites/            # 精灵图（roombacks、backgrounds）
│   └── ui/                 # UI 素材
├── addons/                 # Godot 插件
│   ├── room_items_grid_snap/  # 房间内元件网格对齐
│   └── snappy/             # Snappy 库
├── translations/           # 本地化
│   ├── translations.csv   # 翻译源表
│   └── *.translation      # zh_CN、en 翻译文件
├── designs/                # UI 设计索引
│   ├── ui-index.json      # UI 组件索引
│   └── README.md
└── docs/                   # 文档
    ├── 名词解释.md        # 游戏专有名词
    ├── design/            # 游戏系统与功能设计文档
    └── settings/          # 术语对照、项目关键词
```

## 运行方式

- **F5 运行项目**：启动主菜单 `start_menu.tscn`，选择新游戏/继续游戏后进入 `game_main.tscn`
- **F6 运行当前场景**：直接运行当前打开的场景（可用于单独调试地图编辑器、游戏主场景等）

## Autoload 单例

| 名称 | 用途 |
|------|------|
| `LocaleManager` | 语言/本地化，保存并应用用户选择的 locale |
| `GameTime` | 游戏时间流逝（6 秒 = 1 游戏小时，倍速 1x/2x/6x/96x） |
| `ErosionCore` | 侵蚀等级与预测（隐性/轻度/显性/涌动/莱卡昂暗影） |
| `GameValues` | 从 `game_values.json` 加载数值，供消耗、产出、建设等逻辑 |
| `PersonnelErosionCore` | 研究员侵蚀、被侵蚀、死亡、治愈、灾厄值 |
| `SaveManager` | 存档槽位保存/加载（`user://saves/`） |

## 存档说明

- **游戏存档**：`user://saves/`，存放玩家进度（slot_0~4、autosave）
- **地图编辑器**：`user://maps/`，存放项目级地图（与游戏存档分离，清空存档时不动）

## 开发环境

- 编码：UTF-8
- 换行符：LF

## 相关文档

- [项目概览](docs/design/00-project-overview.md)
- [名词解释](docs/名词解释.md)
- [数据文件说明](datas/README.md)
- [术语对照](docs/settings/00-project-keywords.md)
