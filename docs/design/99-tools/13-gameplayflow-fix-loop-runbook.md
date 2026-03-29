# 13 - GameplayFlow 闭环修复执行手册

## 1. 目标

本手册定义运行失败后的标准闭环：

1. 运行 flow
2. 读取 `report.json` / `junit.xml` / `logs/driver_flow.json`
3. 归因并生成修复计划
4. 用户审批后修改
5. 复验，最多 3 轮（`bounded_auto_fix=3`）

## 2. 标准运行命令

场景 A：

```bash
python tools/game-test-runner/core/flow_runner.py \
  --flow-file flows/suites/regression/gameplay/basic_gameplay_slot0_phase1.json \
  --project-root . \
  --godot-bin godot4
```

场景 B：

```bash
python tools/game-test-runner/core/flow_runner.py \
  --flow-file flows/suites/regression/gameplay/basic_data_slot0_phase1.json \
  --project-root . \
  --godot-bin godot4
```

## 3. 产物与定位

每次运行产物位于：`artifacts/test-runs/<run_id>/`

- `report.json`：结构化结果
- `report.md`：可读摘要
- `junit.xml`：CI 门禁格式
- `logs/stdout.log`、`logs/stderr.log`、`logs/godot.log`
- `logs/driver_flow.json`：驱动步骤回放（动作、响应、耗时）
- `flow_report.json`：flow 文件解析与执行摘要
- `screenshots/*.png`：步骤截图证据

## 4. 失败分类与处理

| 分类 | 判定来源 | 默认处理 |
|---|---|---|
| `VISUAL_LAYOUT_MISMATCH` | `check`/硬规则校验失败 | 修 UI 结构（尺寸/锚点/层级） |
| `VISUAL_SEMANTIC_MISMATCH` | 视觉语义评审失败 | 修样式、文案、视觉关系 |
| `LOGIC_STATE_TRANSITION_ERROR` | `logic_state` 断言失败 | 修状态机或触发条件 |
| `RUNTIME_EXCEPTION` | `stderr/godot.log` 错误摘要 | 优先修脚本错误与资源引用 |
| `TIMEOUT` | `wait` 超时 | 调整等待条件或修性能阻塞 |
| `SELF_HEAL_EXHAUSTED` | 自愈重试后仍失败 | 升级人工处理 |

## 5. 有界自动修复策略

- 最大轮次：3
- 每轮都必须保留：失败证据 -> 原因分析 -> 修复说明
- 连续 2 轮同类阻断错误无改善时，停止自动修复并要求人工决策

## 6. 运行时自愈策略

当运行期间检测到 `runtimeErrors`：

1. 先读取 `logs/stderr.log` 和 `logs/godot.log`
2. 如果是可恢复问题（节点尚未加载、短时资源未就绪），允许 1~2 次重试
3. 如果是脚本错误（`Script Error` / `push_error` 持续出现），直接进入修复轮次

## 7. CI 建议

- PR 同步阻断：`smoke`
- PR 异步：`strict_ui`
- 每日回归：`regression`

`junit.xml` 作为统一门禁输入，`report.json` 用于 Agent 自动归因。
