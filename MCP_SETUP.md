# NotchNoti MCP 集成设置指南

## 步骤 1: 添加 MCP Swift SDK 依赖

### 通过 Xcode 添加包依赖:

1. 打开 `NotchNoti.xcodeproj`
2. 选择项目根节点 "NotchNoti"
3. 选择 "NotchNoti" target
4. 点击 "Package Dependencies" 标签页
5. 点击 "+" 按钮添加包
6. 输入仓库 URL:
   ```
   https://github.com/modelcontextprotocol/swift-sdk.git
   ```
7. 选择版本规则: "Up to Next Major Version" - `0.10.0`
8. 点击 "Add Package"
9. 在产品列表中勾选 `ModelContextProtocol`
10. 点击 "Add Package"

### 或者手动编辑 project.pbxproj:

如果你熟悉 Xcode 项目文件,可以参考现有的 `ColorfulX` 和 `LaunchAtLogin` 依赖格式。

## 步骤 2: 将 MCP 文件添加到 Xcode 项目

1. 在 Xcode 项目导航器中,右键点击 "NotchNoti" 文件夹
2. 选择 "Add Files to NotchNoti..."
3. 导航到 `NotchNoti/MCP` 文件夹
4. 选择所有 `.swift` 文件
5. 确保勾选:
   - ✅ "Copy items if needed"
   - ✅ "Create groups"
   - ✅ Target: NotchNoti
6. 点击 "Add"

## 步骤 3: 配置 Claude Code

在 `~/.config/claude/config.json` 中添加 MCP 服务器配置:

```json
{
  "hooks": {
    "user_prompt_submit": "/Applications/NotchNoti.app/Contents/MacOS/notch-hook hook",
    "pre_tool_use": "/Applications/NotchNoti.app/Contents/MacOS/notch-hook hook",
    "post_tool_use": "/Applications/NotchNoti.app/Contents/MacOS/notch-hook hook",
    "session_start": "/Applications/NotchNoti.app/Contents/MacOS/notch-hook hook",
    "stop": "/Applications/NotchNoti.app/Contents/MacOS/notch-hook hook"
  },
  "mcpServers": {
    "notchnoti": {
      "command": "/Applications/NotchNoti.app/Contents/MacOS/NotchNoti",
      "args": ["--mcp"],
      "env": {}
    }
  }
}
```

## 步骤 4: 修改应用启动参数支持

NotchNoti 需要支持 `--mcp` 参数来启动 MCP 服务器模式,而不是启动完整的 GUI 应用。

这需要在 `main.swift` 中添加命令行参数检测。

## 步骤 5: 构建和测试

```bash
# 构建应用
xcodebuild -scheme NotchNoti -configuration Debug build

# 测试 MCP 服务器 (手动)
/path/to/NotchNoti.app/Contents/MacOS/NotchNoti --mcp
```

## MCP 工具使用示例

在 Claude Code 对话中,我可以调用以下工具:

### 1. 显示进度
```
notch_show_progress({
  "title": "Building project",
  "progress": 0.65,
  "cancellable": true
})
```

### 2. 显示结果
```
notch_show_result({
  "title": "Build Complete",
  "type": "success",
  "message": "15 tests passed in 2.3s"
})
```

### 3. 请求确认
```
notch_ask_confirmation({
  "question": "Delete 3 files?",
  "options": ["Confirm", "Cancel", "Show Details"]
})
```

## MCP 资源访问示例

### 获取会话统计
```
资源 URI: notch://stats/session
返回: JSON 格式的当前工作会话统计
```

### 获取通知历史
```
资源 URI: notch://notifications/history
返回: 最近 10 条通知的 JSON 数组
```

## 故障排查

### MCP 服务器无法启动

1. 检查依赖是否正确添加: `ModelContextProtocol` 框架
2. 检查 Swift 版本: 需要 Swift 6.0+
3. 检查 Xcode 版本: 需要 Xcode 16+

### Claude Code 无法连接

1. 检查 `config.json` 中的路径是否正确
2. 检查应用是否有执行权限
3. 检查 `--mcp` 参数是否被正确处理

### 工具调用失败

1. 检查 Xcode console 中的 `[MCP]` 前缀日志
2. 验证传入参数是否符合 JSON schema
3. 检查 `NotificationManager.shared` 是否正常工作

## 性能考虑

- MCP 服务器使用 `@MainActor` 确保线程安全
- 所有操作都是异步的 (`async/await`)
- 与现有 Hook 系统并存,互不干扰
- stdio 传输,低延迟,高性能

## 下一步

完成基础集成后,可以扩展更多功能:

- [ ] 添加更多工具 (打开视图、自定义内容等)
- [ ] 实现真正的用户交互回调
- [ ] 添加流式进度更新
- [ ] 集成 diff 预览资源
- [ ] 创建自定义 Prompts
