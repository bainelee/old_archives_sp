# Changelog

## 2026-04-02

### Fixed

- 修复 3D 房间悬停在“镜头移动/缩放后、屏幕侧边”场景下偶发失效问题。
- 修复“隐形 UI 拦截鼠标”导致的悬停异常：UI 命中改为仅在 `is_visible_in_tree()` 为真时生效。

### Changed

- 3D 命中链改为事件坐标驱动，避免输入事件坐标与射线采样坐标脱钩。
- `RoomBlockHighlight` pick 碰撞盒高度改为基于房间体积 `room_volume.y` 的完整高度（含最小下限），不再使用不匹配场景布局的薄层方案。
- 回归检查增强诊断输出（`ray_debug`、`ui_block_detail`），并完善 UI 覆盖点的跳过统计，避免误判。

### Verification

- 用户人工复测通过：同区域此前“红点可悬停、蓝点不可悬停”的问题已消失。
- 自动化回归通过（base/zoom/edge/refocus）：
  - `artifacts/test-runs/gameplay_stepwise_chat_plugin_20260402T034845915880Z.json`
  - `artifacts/test-runs/gameplay_stepwise_chat_plugin_20260402T035303032760Z.json`
  - `artifacts/test-runs/gameplay_stepwise_chat_plugin_20260402T035214828951Z.json`
  - `artifacts/test-runs/gameplay_stepwise_chat_plugin_20260402T035231192316Z.json`

### Files

- `scripts/game/game_main.gd`
- `scripts/game/game_main_input.gd`
- `scripts/rooms/room_block_highlight.gd`
- `scripts/test/test_driver_actions.gd`
- `flows/suites/regression/gameplay/room_hover_click_projection_matrix_slot0.json`
- `flows/suites/regression/gameplay/room_hover_click_projection_matrix_zoom_slot0.json`
- `flows/suites/regression/gameplay/room_hover_click_projection_matrix_edge_slot0.json`
- `flows/suites/regression/gameplay/room_hover_click_projection_matrix_refocus_slot0.json`
- `tools/game-test-runner/mcp/chat_progress_templates.json`
- `docs/testing/未完全修复.md`
