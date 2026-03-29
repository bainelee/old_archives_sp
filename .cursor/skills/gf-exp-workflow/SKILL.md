---
name: gf-exp-workflow
description: 执行 GF-EXP 全流程：在修复分支运行 GameplayFlow 并收敛 bug，提炼 EXP 资产，仅同步 allowlist 内 EXP 文件回 main，再从 main 创建重修分支。用于用户提到“执行EXP流程”“执行GF-EXP流程”“带exp的gameplayflow”时。
---

# GF-EXP Workflow

## 目标

把“修 bug”与“沉淀 EXP”拆分成两个可审计阶段，避免手工清理残留。

## 输入口令

- 执行 EXP 流程
- 执行 GF-EXP 流程
- 进行一次带有 exp 的 gameplayflow

## 默认阶段协议

1. **Phase A / 修复分支收敛**
   - 从 `main` 创建修复分支。
   - 运行 GameplayFlow 验证脚本并迭代修复，直到通过。
2. **Phase B / EXP 提炼**
   - 将定位路径、修复策略、回归要点沉淀为 EXP 文件。
3. **Phase C / 仅同步 EXP 到 main**
   - 返回 `main`，只同步 allowlist 内 EXP 资产。
   - 审计 diff，若出现越界文件立即停止。
4. **Phase D / main 上正式重修**
   - 从 `main` 新建重修分支，重新实施代码修复。

## 标准入口

- 脚本入口：`tools/game-test-runner/scripts/run_gf_exp_cycle.ps1`
- allowlist：`tools/game-test-runner/config/gf_exp_allowlist.json`
- GameplayFlow 验证入口：`tools/game-test-runner/scripts/run_gameplay_regression.ps1`（基础测试 phase1/2 + 基础数据 resource_reconcile）

## 执行要求

- 每阶段结束都输出阶段结果、变更范围、下一步动作。
- 只把 EXP 资产同步到 `main`，不把修复代码混入 EXP 同步提交。
- 若仓库脏工作区影响审计，先提示并中断流程。

## EXP 资产硬约束（强制）

- EXP 必须写入 skill 体系内，默认落点：
  - `.cursor/skills/gf-exp-workflow/EXP_LIBRARY.md`
  - 或对应技能目录下的同级参考文件。
- 禁止把 EXP 记到 `docs/testing/*bug*`、`retrospective`、临时测试记录等 bug 专项文档。
- EXP 内容必须是“问题类型级”方法，不得出现：
  - 具体 bug 标题/编号/时间线
  - 一次性运行产物路径
  - 仅对单次故障成立的临时结论

## EXP 写作模板（类型级）

1. 问题类型定义（触发条件/外在症状）
2. 最快定位路径（3-5 步）
3. 稳定主断言与可观测点
4. 最小修复策略与反模式
5. 回归门槛（最少重复通过次数）

## 术语说明

- `exp-overlay-input-debug`：偏“覆盖层输入穿透”调试方法。
- `gf-exp-workflow`：面向 GameplayFlow 修复的完整 git 流程编排。
