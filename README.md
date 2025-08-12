# NotchDrop 🔔

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange" />
  <img src="https://img.shields.io/badge/license-MIT-green" />
</p>

**将 MacBook 的刘海变成智能通知中心** - 一个创新的 macOS 原生应用，让原本"浪费"的刘海空间变成高效的开发工具监控区域。

## ✨ 特性

### 🎯 核心功能
- **刘海通知显示** - 在 MacBook 刘海区域优雅地显示通知
- **HTTP API 服务** - 通过简单的 REST API 发送通知（端口 9876）
- **通知队列管理** - 智能队列系统，不丢失任何通知
- **优先级系统** - 4 级优先级（低/普通/高/紧急）
- **通知合并** - 自动合并相同来源的连续通知
- **历史记录** - LRU 缓存管理，保存最近 100 条通知
- **Diff 预览** - 支持代码改动对比预览窗口
- **通知声音** - 可配置的系统提示音

### 🎨 视觉效果
- **动画效果** - 流畅的进入/退出动画
- **紧急通知特效** - 脉冲背景、彩色阴影、缩放动画
- **深色模式支持** - 完美适配 macOS 深色/浅色主题
- **渐变背景** - 紧急通知显示醒目的渐变背景
- **动态显示时长** - 根据内容长度和优先级自动调整

### 🔌 Claude Code 集成
- **深度集成** - 完美配合 Claude Code 使用
- **智能过滤** - 自动过滤不重要的操作
- **实时监控** - 查看 AI 正在执行的操作
- **等待提醒** - Claude 需要确认时紧急通知

## 📦 安装

### 方法 1：下载 DMG（推荐）
1. 从 [Releases](https://github.com/QingChang1204/DynamicNotch/releases) 下载最新的 `NotchDrop-x.x.x.dmg`
2. 双击打开 DMG 文件
3. 将 `NotchNotifier.app` 拖到 Applications 文件夹
4. 首次运行时右键选择"打开"

### 方法 2：从源码构建
```bash
git clone https://github.com/QingChang1204/DynamicNotch.git
cd DynamicNotch
./build-dmg.sh  # 生成 DMG 安装包
```

## 🚀 使用方法

### 基础 API

发送通知到 `http://localhost:9876/notify`:

```bash
curl -X POST http://localhost:9876/notify \
  -H "Content-Type: application/json" \
  -d '{
    "title": "构建成功",
    "message": "项目构建完成",
    "type": "success",
    "priority": 2
  }'
```

### 参数说明

| 参数 | 类型 | 说明 | 可选值 |
|------|------|------|--------|
| title | string | 通知标题 | - |
| message | string | 通知内容 | - |
| type | string | 通知类型 | info, success, warning, error, progress |
| priority | number | 优先级 | 0 (低), 1 (普通), 2 (高), 3 (紧急) |
| metadata | object | 元数据 | 自定义键值对 |

### 优先级效果

- **0 (低)**: 0.8 秒显示，无特效
- **1 (普通)**: 1 秒显示，标准动画
- **2 (高)**: 1.5 秒显示，醒目提示
- **3 (紧急)**: 2 秒显示，脉冲特效 + 渐变背景

## 🤖 Claude Code 集成

### 快速配置

1. 复制配置到你的项目：
```bash
cp -r /path/to/DynamicNotch/.claude /your/project/
```

2. 自动获得以下通知：
- ✏️ 文件修改前警告
- 🔔 需要确认时提醒  
- ✨ 任务完成通知
- ⚠️ 重要命令执行提醒

### 配置文件

- **标准版**: `.claude/settings.json` - 适度通知
- **专注版**: `.claude/settings-focused.json` - 最少干扰

## 💻 其他集成示例

### Git Hooks
```bash
# .git/hooks/post-commit
#!/bin/bash
curl -X POST http://localhost:9876/notify \
  -H "Content-Type: application/json" \
  -d '{"title":"Git 提交","message":"提交成功","type":"success"}'
```

### npm Scripts
```json
{
  "scripts": {
    "build": "webpack && curl -X POST http://localhost:9876/notify -d '{\"title\":\"构建完成\",\"message\":\"Webpack 构建成功\"}' -H 'Content-Type: application/json'"
  }
}
```

### VS Code / Cursor 任务
```json
{
  "tasks": [{
    "label": "Build with Notification",
    "command": "npm run build && curl -X POST http://localhost:9876/notify -d '{\"title\":\"✅ 完成\",\"message\":\"构建成功\"}' -H 'Content-Type: application/json'"
  }]
}
```

## 🎯 使用场景

- **开发监控** - 实时查看 Claude Code 的操作
- **构建通知** - 长时间构建完成提醒
- **测试结果** - 测试通过/失败通知
- **部署状态** - CI/CD 流程监控
- **自定义提醒** - 任何需要通知的场景

## 🛠 技术栈

- **SwiftUI** - 原生 macOS UI 框架
- **Network.framework** - 原生网络框架
- **Combine** - 响应式编程
- **Swift 5.9** - 现代 Swift 特性

## 📋 系统要求

- macOS 13.0 (Ventura) 或更高版本
- 带刘海屏的 MacBook Pro (2021+) 或 MacBook Air (2022+)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

主要改进方向：
- [ ] 双向交互支持
- [ ] 更多通知样式
- [ ] 通知声音
- [ ] 云同步历史

## 📄 许可

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- 基于 [winstonkhoe/DynamicNotch](https://github.com/winstonkhoe/DynamicNotch) fork 开发
- winstonkhoe/DynamicNotch 基于 [Lakr233/NotchDrop](https://github.com/Lakr233/NotchDrop) 原始项目
- Claude (Anthropic) 协助开发和优化
- 所有贡献者和测试者

## 💬 联系

- GitHub Issues: [报告问题](https://github.com/QingChang1204/DynamicNotch/issues)
- 功能建议: 欢迎在 Issues 中讨论

---

<p align="center">
  Made with ❤️ for developers who love their MacBook notch
</p>