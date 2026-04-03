# 梗概文件命名规范

## 目的

统一梗概、记录、回顾类文件命名，避免历史工具链词根混入后续文档。

## 基本格式

- 文档：`<主题>-<用途>-<版本可选>.md`
- 数据：`<场景>_<动作>_<目标>.json`
- 脚本：`<系统>_<目的>_smoke.gd`

## 示例

- `exploration-ui-assertions-v1.md`
- `new_game_enter_world_step.json`
- `exploration_regression_smoke.gd`

## 禁用词根

后续新命名中避免出现“历史自动化链路”的专有词根与缩写，统一使用中性业务语义。

## 推荐语义词

- `summary`
- `record`
- `validation`
- `assertion`
- `smoke`
