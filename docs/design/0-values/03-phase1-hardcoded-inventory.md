# 03 - Phase 1 硬编码盘点清单

## 目的

本清单用于落实“数据驱动改造 Phase 1”：把核心循环中仍写在脚本里的可调参数迁移到 `datas/*.json`，并由 `datas/schemas/*.schema.json` 提供字段解释。

---

## 1. 时间系统（Time）

| 来源文件 | 符号/位置 | 当前值 | 目标配置文件 | 目标字段 |
|------|------|------|------|------|
| `scripts/core/game_time.gd` | `REAL_SECONDS_PER_GAME_HOUR` | `3.0` | `datas/time_system.json` | `time.real_seconds_per_game_hour` |
| `scripts/core/game_time.gd` | `GAME_HOURS_PER_DAY` | `24` | `datas/time_system.json` | `calendar.hours_per_day` |
| `scripts/core/game_time.gd` | `GAME_DAYS_PER_WEEK` | `7` | `datas/time_system.json` | `calendar.days_per_week` |
| `scripts/core/game_time.gd` | `GAME_DAYS_PER_MONTH` | `30` | `datas/time_system.json` | `calendar.days_per_month` |
| `scripts/core/game_time.gd` | `GAME_MONTHS_PER_YEAR` | `12` | `datas/time_system.json` | `calendar.months_per_year` |
| `scripts/core/game_time.gd` | `SPEED_1X/2X/6X/96X` | `1/2/6/96` | `datas/time_system.json` | `speed_presets` |
| `scripts/core/game_time.gd` | `clampf(v, 1.0, 96.0)` | `1~96` | `datas/time_system.json` | `speed_range.min/max` |

---

## 2. 清理与建设推进（Cleanup/Construction Runtime）

| 来源文件 | 符号/位置 | 当前值 | 目标配置文件 | 目标字段 |
|------|------|------|------|------|
| `scripts/game/game_main_cleanup.gd` | `delta / GameTime.REAL_SECONDS_PER_GAME_HOUR` | 依赖时间常量 | `datas/time_system.json` | `time.real_seconds_per_game_hour` |
| `scripts/game/game_main_construction.gd` | `delta / GameTime.REAL_SECONDS_PER_GAME_HOUR` | 依赖时间常量 | `datas/time_system.json` | `time.real_seconds_per_game_hour` |
| `scripts/game/game_main_built_room.gd` | `MAX_HOURS_PER_FRAME` | `24` | `datas/construction_system.json` | `production.max_hours_per_frame` |
| `scripts/game/game_main_built_room.gd` | `* 24`（24h 暂停阈值） | `24` | `datas/construction_system.json` | `production.creation_pause_check_hours` |

---

## 3. 研究员基础参数（Researcher）

| 来源文件 | 符号/位置 | 当前值 | 目标配置文件 | 目标字段 |
|------|------|------|------|------|
| `scripts/core/personnel_erosion_core.gd` | `COGNITION_PER_RESEARCHER_PER_DAY` | `24` | `datas/researcher_system.json` | `cognition.consumption_per_researcher_per_day` |
| `scripts/core/personnel_erosion_core.gd` | `COGNITION_PER_RESEARCHER_PER_HOUR` | `1` | `datas/researcher_system.json` | `cognition.consumption_per_researcher_per_hour` |
| `scripts/core/personnel_erosion_core.gd` | `COGNITION_CRISIS_MAX` | `3` | `datas/researcher_system.json` | `cognition.crisis.max_stacks` |
| `scripts/core/personnel_erosion_core.gd` | `CALAMITY_PER_IMPAIRED_PER_DAY` | `10` | `datas/researcher_system.json` | `cognition.crisis.calamity_per_impaired_per_day` |

---

## 4. 侵蚀与治愈参数（Erosion）

| 来源文件 | 符号/位置 | 当前值 | 目标配置文件 | 目标字段 |
|------|------|------|------|------|
| `scripts/core/personnel_erosion_core.gd` | `EROSION_PROB_EXTREME` | `80` | `datas/erosion_system.json` | `erosion_probability.extreme` |
| `scripts/core/personnel_erosion_core.gd` | `EROSION_PROB_EXPOSED` | `50` | `datas/erosion_system.json` | `erosion_probability.exposed` |
| `scripts/core/personnel_erosion_core.gd` | `EROSION_PROB_WEAK` | `20` | `datas/erosion_system.json` | `erosion_probability.weak` |
| `scripts/core/personnel_erosion_core.gd` | `EROSION_RISK_THRESHOLD` | `5` | `datas/erosion_system.json` | `risk.threshold_per_7_days` |
| `scripts/core/personnel_erosion_core.gd` | `CURE_INTERVAL_DAYS` | `3` | `datas/erosion_system.json` | `cure.interval_days` |
| `scripts/core/personnel_erosion_core.gd` | `CURE_PROB_ADEQUATE` | `30` | `datas/erosion_system.json` | `cure.probability.adequate` |
| `scripts/core/personnel_erosion_core.gd` | `CURE_PROB_PERFECT` | `80` | `datas/erosion_system.json` | `cure.probability.perfect` |
| `scripts/core/personnel_erosion_core.gd` | `IMMUNITY_DAYS` | `7` | `datas/erosion_system.json` | `cure.immunity_days` |
| `scripts/core/personnel_erosion_core.gd` | `DEATH_DAYS_HALF` | `112` | `datas/erosion_system.json` | `death_curve.half_days` |
| `scripts/core/personnel_erosion_core.gd` | `DEATH_DAYS_FULL` | `140` | `datas/erosion_system.json` | `death_curve.full_days` |
| `scripts/core/personnel_erosion_core.gd` | `DEATH_CURVE_EXP` | `3.1` | `datas/erosion_system.json` | `death_curve.exponent` |
| `scripts/core/personnel_erosion_core.gd` | `CALAMITY_PER_ERODED_PER_HOUR` | `1` | `datas/erosion_system.json` | `calamity.per_eroded_per_hour` |
| `scripts/core/personnel_erosion_core.gd` | `CALAMITY_MAX` | `30000` | `datas/erosion_system.json` | `calamity.max_value` |

---

## 5. 庇护核心参数（Shelter）

| 来源文件 | 符号/位置 | 当前值 | 目标配置文件 | 目标字段 |
|------|------|------|------|------|
| `scripts/core/game_values.gd` + `datas/game_values.json` | `shelter.level_min/max` | `1/5` | `datas/shelter_system.json` | `shelter.level_min/level_max` |
| `scripts/core/game_values.gd` + `datas/game_values.json` | `energy_per_room_max` | `5` | `datas/shelter_system.json` | `shelter.energy_per_room_max` |
| `scripts/core/game_values.gd` + `datas/game_values.json` | `room_types_no_shelter` | `[4,9,10]` | `datas/shelter_system.json` | `shelter.room_types_no_shelter` |
| `scripts/core/game_values.gd` + `datas/game_values.json` | `energy_levels[]` | 各等级数组 | `datas/shelter_system.json` | `shelter.energy_levels[]` |

---

## 6. 迁移说明

- Phase 1 采用“兼容迁移”：先新增配置文件和读取接口，再逐步减少脚本硬编码。
- `datas/game_values.json` 保留“基础经济/产出”数据，拆分后的系统配置优先从各自 JSON 读取。
- 所有字段解释以 `datas/schemas/*.schema.json` 的 `description` 为准。
