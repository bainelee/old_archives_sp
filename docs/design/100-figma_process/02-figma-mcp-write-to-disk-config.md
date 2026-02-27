# Figma MCP write-to-disk 配置指南

当 `get_design_context` 返回错误 **"Path for asset writes as tool argument is required for write-to-disk option"** 时，说明 Figma Desktop 的图片资源写入磁盘功能已开启，但未配置写入路径。

## 原因

Figma Desktop MCP 的 **Image settings** 有三种模式：

| 模式 | 说明 | 是否需要路径 |
|------|------|--------------|
| **Placeholders**（已弃用） | 跳过图片提取，用占位符替代 | 否 |
| **Download assets** | 将图标、图片等资源下载并写入项目 | **是** |
| **Local server** | 使用本地 localhost 链接，不写入磁盘 | 否 |

当前若选择了 **Download assets**，MCP 必须知道写入路径才能工作。

## 解决方案

### 方案 A：改用 Local server（推荐，快速修复）★

不写入磁盘，使用 localhost 提供图片，`get_design_context` 可正常返回：

1. 打开 **Figma Desktop**，打开你的设计文件
2. 切到 **Dev Mode**（Shift+D）
3. 右侧 **Inspect** 面板 → 找到 **MCP server** 区域
4. 点击 **「Open settings modal」**（或齿轮图标进入设置）
5. 在 **Image settings** 下拉中，将 **「Download assets」** 改为 **「Local server」**
6. 关闭设置，**重启 Figma Desktop**（如仍有问题）
7. 在 Cursor 中再次让 Agent 调用 `get_design_context`

这样 `get_design_context` 将不再尝试写入磁盘，错误会消失。

### 方案 B：为 Download assets 配置项目路径

如需把 Figma 资源实际写入到项目：

1. 打开 **Figma Desktop** → Dev Mode → **Open settings modal**
2. 选择 **Image settings** → **Download assets**
3. 查看是否有 **「Project path」** 或 **「Asset write path」** 等输入框
4. 填入项目目录，例如：`d:\GODOT_Test\old-archives-sp`（Windows）或 `D:/GODOT_Test/old-archives-sp`
5. 若设置中有「工作区路径」或类似选项，选择当前项目根目录

> 注：Figma Desktop 的 MCP 设置界面可能因版本不同而略有差异，若未找到路径配置，可尝试在 Cursor 的 MCP 配置中传入路径（见方案 C）。

### 方案 C：通过 Cursor MCP 配置传入路径（若支持）

若 Figma MCP 支持通过 MCP 客户端传入路径，可在项目 `.cursor/mcp.json` 或全局 Cursor MCP 配置中，为 Figma Desktop 服务器添加环境变量或 input 参数。当前项目使用的配置：

```json
{
  "mcpServers": {
    "Figma Desktop": {
      "url": "http://127.0.0.1:3845/mcp",
      "headers": {}
    }
  }
}
```

若 Figma 文档或更新说明提到支持 `FIGMA_ASSET_PATH`、`projectPath` 等参数，可按其说明在配置中增加 `env` 或 `args`。

## 验证

配置完成后：

1. 在 Figma 中选中要同步的 Frame（如 node-id 6:2）
2. 在 Cursor 中提示 Agent：「调用 get_design_context 获取该设计的数据」
3. 若不再出现 "Path for asset writes" 错误，且能返回 layout、fills 等数据，则配置成功

## 相关链接

- [Figma MCP 本地服务器安装](https://developers.figma.com/docs/figma-mcp-server/local-server-installation/)
- [Figma MCP 工具与提示](https://developers.figma.com/docs/figma-mcp-server/tools-and-prompts/)
