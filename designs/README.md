# UI 设计索引

本目录存放 old-archives 项目的 UI 设计索引资源。

## 文件说明

| 文件 | 说明 |
|------|------|
| `ui-index.json` | UI 组件索引 |
| `scripts/build_ui_index.py` | 从 .tscn 与 docs 解析并生成索引的脚本 |

## 重建索引

当 `scenes/ui/*.tscn` 或 `docs/design/*.md` 有变更时，可运行：

```bash
python designs/scripts/build_ui_index.py
```

需要 Python 3，仅使用标准库。输出覆盖 `designs/ui-index.json`。
