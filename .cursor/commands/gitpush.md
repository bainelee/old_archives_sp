# git-push：保存项目并推送至 Git 远端

## 概述

将当前工作区的所有变更保存并推送到 Git 远端仓库。适用于 Windows + PowerShell 环境，正确支持中文提交信息（UTF-8 无乱码）。

## 步骤

1. **提醒用户保存文件**  
   若用户未开启自动保存，建议先执行 `Ctrl+K S` 保存所有文件。

2. **暂存所有变更**
   ```bash
   git add .
   ```

3. **提交变更（中文编码安全）**  
   Windows PowerShell 下 `git commit -m "中文"` 会乱码，必须使用文件方式：
   - 将提交信息写入 UTF-8 无 BOM 的临时文件 `.git-commit-msg`
   - 使用 `git commit -F .git-commit-msg` 提交
   - **提交信息生成规则**（按优先级）：
     - 用户在本命令后附带的说明 → 直接使用
     - 若无附带说明 → 根据 `git diff --cached` 和 `git status` 分析变更内容，**按实际改动生成合适的提交信息**，例如：
       - 新增功能 → `feat: 简短描述`（如 `feat: 新增存档系统与暂停菜单`）
       - 修复问题 → `fix: 简短描述`
       - 文档/设计 → `docs: 简短描述`
       - 重构/配置 → `refactor:` / `chore:`
     - **禁止** 无差别使用 `chore: 保存并同步`，除非变更确实仅为零散同步

   PowerShell 推荐写法（无 BOM UTF-8）：
   ```powershell
   $utf8 = [System.Text.UTF8Encoding]::new($false)
   [System.IO.File]::WriteAllText(".git-commit-msg", "提交信息内容", $utf8)
   git commit -F .git-commit-msg
   Remove-Item .git-commit-msg -ErrorAction SilentlyContinue
   ```

4. **推送到远端**
   ```bash
   git push
   ```

## 特殊情况处理

- **无变更**：若 `git status --porcelain` 无输出，告知用户“无变更，跳过提交与推送”。
- **提交失败**：检查是否有未解决的冲突或 pre-commit 钩子失败，输出错误信息供用户排查。
- **推送失败**：可能是远端未配置、权限不足或需先拉取，给出相应提示。

## 执行方式

在终端中执行上述命令序列，使用项目根目录作为工作目录。  
**关键**：在用户未提供提交信息时，先执行 `git diff --cached --stat` 和 `git status` 查看变更，再根据变更类型与涉及文件撰写描述性提交信息。
