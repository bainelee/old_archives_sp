# 场景编写指南（v1）

## 1. 目标
新增一个可被 runner 调用的测试场景，并以最小成本给出稳定通过/失败结论。

## 2. 推荐结构
- 场景：`scenes/test/<name>_test.tscn`
- 脚本：`scripts/test/<name>_test.gd`

参考：
- `scenes/test/exploration_smoke_test.tscn`
- `scripts/test/exploration_smoke_test.gd`

## 3. 脚本约定
- 成功：`print("[<Name>] PASS")` + `get_tree().quit(0)`
- 失败：`push_error("[<Name>] FAIL: ...")` + `get_tree().quit(1)`
- 尽量不要依赖复杂 UI 操作作为首版断言
- 优先做“纯状态断言 + 存档往返断言”

## 4. 注册到场景表
编辑：
- `tools/game-test-runner/core/scenario_registry.py`

新增 `ScenarioDef`，至少包含：
- `name`
- `system`
- `scene`
- `profiles`
- `supported_modes`

## 5. 运行验证
```powershell
python "tools/game-test-runner/core/cli.py" --system <system> --project-root "." --scenario <scenario_name> --dry-run
```

如果要真实跑（非 dry-run）：
```powershell
python "tools/game-test-runner/core/cli.py" --system <system> --project-root "." --scenario <scenario_name> --godot-bin "<GodotExePath>"
```

## 6. 质量门槛（建议）
- 同一命令连续执行 3 次，结果一致
- 失败时 `report.json` 可定位到失败类别与证据路径
- 场景执行时长不超过 60 秒（smoke 档）
