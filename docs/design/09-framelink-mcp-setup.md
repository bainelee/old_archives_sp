# Framelink MCP for Figma 配置说明

[Framelink MCP](https://github.com/GLips/Figma-Context-MCP) 通过 Figma REST API 提供 layout、styling 等设计数据，相比 Figma Desktop MCP 能更稳定地返回结构化数据，便于同步到 Godot。

## 前置要求

- 需要 **Figma Personal Access Token**（只读权限即可）
- 无需 Figma Desktop 运行

## 1. 创建 Figma Access Token

1. 打开 [Figma 设置](https://www.figma.com/settings)
2. 左侧选择 **Security**
3. 找到 **Personal access tokens**，点击 **Generate new token**
4. 输入名称，勾选 **File content**、**Dev resources** 的读权限
5. 点击 **Generate token**，复制生成的 token（只显示一次）

详见 [Figma 官方文档](https://help.figma.com/hc/en-us/articles/8085703771159-Manage-personal-access-tokens)。

## 2. 配置 MCP

编辑 `.cursor/mcp.json`，将 `YOUR_FIGMA_API_KEY` 替换为你的 token：

```json
"env": {
  "FIGMA_API_KEY": "粘贴你的 token 到这里"
}
```

或使用命令行参数（不推荐，token 会出现在配置中）：

```json
"args": ["/c", "npx", "-y", "figma-developer-mcp", "--figma-api-key=你的token", "--stdio"]
```

## 3. 重启 Cursor

修改 MCP 配置后，需重启 Cursor 或重新加载 MCP 使配置生效。

## 4. 使用流程

1. 在 Figma 中右键目标 Frame/Group → **Copy/Paste as** → **Copy link to selection**
2. 在 Cursor 中粘贴链接，例如：
   ```
   https://www.figma.com/design/diDiJC5JoDCH6ljTZpbw9e/testpage_cursor_figma?node-id=6-2
   ```
3. 对 Agent 说：「用 Framelink MCP 的 get_figma_data 获取该设计数据，并同步到 test_figma_page.tscn」

Framelink MCP 的 `get_figma_data` 工具会返回 layout、颜色、尺寸等结构化数据，Agent 可据此直接编辑 `.tscn`。

## 与 Figma Desktop MCP 对比

| 特性 | Framelink MCP | Figma Desktop MCP |
|------|---------------|-------------------|
| 需要 Figma Desktop | 否 | 是 |
| 需要 API Token | 是 | 否 |
| 数据返回 | 结构化，压缩约 90% | 依赖实现，可能不完整 |
| 适用场景 | 通过链接获取任意文件 | 当前选中节点 |

可同时配置两者，按需选用。
