---
name: plan-subagent-auto
description: Enforces automatic subagent strategy generation for all plan-related requests. Use when creating a new plan, refining an existing plan, or when user mentions plan mode/计划/方案 to ensure the plan includes subagent roles, triggers, parallelization, and handoff outputs.
---

# Plan Subagent Auto

## 目标

当任务与 Plan 相关时，自动把“子代理使用方案”写入 Plan，无需用户额外提醒。

## 触发条件

出现以下任一情况时必须启用本技能：

- 用户要求“做计划 / 给出 plan / 进入 plan 模式”
- 用户在已有计划上追加新要求
- 用户要求拆分执行、并行推进、分工方案
- 上下文明确提到 `plan`、`Plan 模式`、`计划更新`

## 强制输出要求

每个 Plan 必须包含独立小节：`子代理使用方案`，且至少包含以下字段：

1. `子代理类型`
   - 为每个子任务指定 `explore` / `generalPurpose` / `shell` / `browser-use` / `best-of-n-runner` 之一
2. `任务分工`
   - 说明每个子代理负责什么，不可重叠
3. `并行策略`
   - 标记哪些任务可并行，哪些必须串行与依赖关系
4. `触发条件`
   - 说明在什么条件下启动该子代理（如“需要大范围探索代码库时”）
5. `交付物`
   - 规定子代理返回内容格式（例如：文件清单、风险点、命令结果、建议结论）

## 生成流程

1. 先产出主计划目标与步骤。
2. 对每一步判断是否可子代理化。
3. 补充 `子代理使用方案` 小节（满足上方 5 项）。
4. 若是“追加需求”，同时更新已有计划与子代理分工，避免冲突。
5. 最终自检：没有 `子代理使用方案` 则计划不合格，必须补齐。

## 默认优先级

- 大范围代码探索优先 `explore`
- 多步研究与整理优先 `generalPurpose`
- 纯命令执行优先 `shell`
- 需要浏览器操作优先 `browser-use`
- 需要隔离并行实验优先 `best-of-n-runner`

## 输出模板（可直接复用）

```markdown
## 子代理使用方案
- 子代理类型：...
- 任务分工：...
- 并行策略：...
- 触发条件：...
- 交付物：...
```
