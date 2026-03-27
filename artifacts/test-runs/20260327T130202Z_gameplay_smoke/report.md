# Test Report

- run_id: `20260327T130202Z_gameplay_smoke`
- status: `failed`
- mode: `local`
- exit_code: `1`
- error: `driver step failed: click`

## Primary Failure
- step_id: `click_missing_target_probe`
- category: `click_target_missing`
- expected: `target should exist in scene tree for this step`
- actual: `click failed: TARGET_NOT_FOUND click target not found`
- artifacts:
  - `logs/driver_flow.json`
  - `logs/godot.log`
  - `logs/stderr.log`
  - `logs/stdout.log`
  - `run_meta.json`
  - `screenshots/visual_ui_button_diff.png`
  - `screenshots/visual_ui_button_diff_annotated.png`
