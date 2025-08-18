# NotchNoti 🔔 - MacBook 刘海通知中心（超酷动画版）

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange" />
  <img src="https://img.shields.io/badge/license-MIT-green" />
</p>

**将 MacBook 的刘海变成智能通知中心** - 一个创新的 macOS 原生应用，让原本"浪费"的刘海空间变成高效的开发工具监控区域。

🎬 **全新升级**：14种通知类型，每种都有独特的视觉动画效果！从粒子雨到震动效果，从波纹扩散到渐变背景，让每个通知都成为视觉享受。

## ✨ 特性

### 🎯 核心功能
- **刘海通知显示** - 在 MacBook 刘海区域优雅地显示通知
- **Unix Socket 通信** - 本地高性能通信通道 (`/tmp/notchnoti.sock`)，无需占用网络端口
- **通知队列管理** - 智能队列系统，不丢失任何通知
- **优先级系统** - 4 级优先级（低/普通/高/紧急）
- **通知合并** - 自动合并相同来源的连续通知
- **历史记录** - LRU 缓存管理，保存最近 100 条通知
- **Diff 预览** - 支持代码改动对比预览窗口
- **多语言支持** - 简体中文/英文界面切换
- **触感反馈** - 支持系统触控板震动反馈
- **通知声音** - 可配置的系统提示音

### 🎨 全新视觉效果（超酷动画升级！）

#### 🌟 14种通知类型，每种都有独特动画
- **✅ Success** - 勾号弹性缩放 + 绿色光晕 + 渐变背景
- **❌ Error** - 震动效果 + 红橙渐变 + 动态光晕
- **⚠️ Warning** - 脉冲闪烁 + 动态阴影
- **ℹ️ Info** - 波纹扩散 + 呼吸效果
- **🔗 Hook** - 链接弹性动画 + 持续脉冲
- **🔧 Tool Use** - 360°旋转 + 摇摆动画
- **⏳ Progress** - 渐变圆环循环旋转
- **🎉 Celebration** - 金色星星粒子雨 + 弹跳动画
- **⏰ Reminder** - 钟摆摇摆效果
- **⬇️ Download** - 下跳动画 + 圆形进度条
- **⬆️ Upload** - 上跳动画 + 圆形进度条
- **🔒 Security** - 红色警示闪烁 + 脉冲光晕
- **🤖 AI** - 动态渐变背景 + 呼吸脉冲
- **🔄 Sync** - 360°持续旋转

#### 🎭 高级视觉特效
- **粒子系统** - celebration 类型的金色星星粒子雨
- **动态渐变** - AI/celebration/security 等类型的动态背景
- **光晕效果** - 紧急通知的呼吸光晕
- **进度指示** - 上传/下载的实时进度显示
- **ProMotion 优化** - 完美支持 120Hz 刷新率
- **GPU 加速** - 所有动画使用 Metal 渲染，超级流畅

### 🔌 Claude Code 集成
- **一键配置** - 通过设置界面自动配置 Claude Code Hooks
- **智能检测** - 自动检测 Claude Code 安装状态
- **Hook 集成** - 自动注入 notch-hook 二进制文件
- **智能过滤** - 自动过滤不重要的操作
- **实时监控** - 查看 AI 正在执行的操作
- **等待提醒** - Claude 需要确认时紧急通知
- **工作目录同步** - 自动跟踪当前工作目录

## 📦 安装

### 方法 1：下载 DMG（推荐）
1. 从 [Releases](https://github.com/QingChang1204/DynamicNotch/releases) 下载最新的 `NotchNoti-x.x.x.dmg`
2. 双击打开 DMG 文件
3. 将 `NotchNoti.app` 拖到 Applications 文件夹
4. 首次运行时右键选择"打开"

### 方法 2：从源码构建
```bash
git clone https://github.com/QingChang1204/DynamicNotch.git
cd DynamicNotch
./build-dmg.sh  # 生成 DMG 安装包
```

## 🚀 使用方法

### Unix Socket API

通过 Unix Socket 发送通知到 `/tmp/notchnoti.sock`:

```bash
# 使用 echo 和 nc (netcat) 发送通知
echo '{"title": "✅ 构建成功", "message": "项目构建完成", "type": "success", "priority": 2}' | nc -U /tmp/notchnoti.sock

# 或使用 Python 示例
python3 -c "
import socket
import json

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect('/tmp/notchnoti.sock')

# 成功通知 - 带勾号动画和绿色光晕
notification = {
    'title': '✅ 构建成功',
    'message': '项目构建完成',
    'type': 'success',
    'priority': 2
}
sock.send(json.dumps(notification).encode())
sock.close()
"

# Node.js 示例
node -e "
const net = require('net');
const client = net.createConnection('/tmp/notchnoti.sock');

const notification = {
    title: '🎉 里程碑达成',
    message: '恭喜！项目突破1000个Star',
    type: 'celebration',
    priority: 3
};

client.write(JSON.stringify(notification));
client.end();
"
```

### 参数说明

| 参数 | 类型 | 说明 | 可选值 |
|------|------|------|--------|
| title | string | 通知标题 | - |
| message | string | 通知内容 | - |
| type | string | 通知类型 | info, success, warning, error, hook, toolUse, progress, celebration, reminder, download, upload, security, ai, sync |
| priority | number | 优先级 | 0 (低), 1 (普通), 2 (高), 3 (紧急) |
| metadata | object | 元数据 | 自定义键值对，如 progress: "0.5" |

### 优先级效果

- **0 (低)**: 0.8 秒显示，无特效
- **1 (普通)**: 1 秒显示，标准动画
- **2 (高)**: 1.5 秒显示，醒目提示
- **3 (紧急)**: 2 秒显示，脉冲特效 + 渐变背景

## 🤖 Claude Code 集成

### 自动配置（推荐）

1. **打开 NotchNoti 设置界面**
   - 点击菜单栏图标 > 设置
   - 或使用快捷键 `⌘,`

2. **Claude Code 集成面板**
   - 系统会自动检测 Claude Code 安装状态
   - 点击"配置 Claude Code Hooks"按钮
   - 自动完成 Hook 配置

3. **自动获得以下通知**：
   - ✏️ 文件修改前警告
   - 🔔 需要确认时提醒  
   - ✨ 任务完成通知
   - ⚠️ 重要命令执行提醒
   - 🔧 工具使用通知
   - 📂 文件操作提醒

### 手动配置

如需手动配置，NotchNoti 会自动生成并管理 Claude Code 的 settings.json，包含：
- Hook 二进制路径配置
- 事件监听器配置
- 通知过滤规则

## 💻 其他集成示例

### Git Hooks
```bash
# .git/hooks/post-commit
#!/bin/bash
echo '{"title":"✅ Git 提交","message":"提交成功！看看勾号动画","type":"success"}' | nc -U /tmp/notchnoti.sock

# .git/hooks/pre-push
#!/bin/bash
echo '{"title":"⬆️ Git Push","message":"正在推送到远程仓库...","type":"upload","metadata":{"progress":"0.5"}}' | nc -U /tmp/notchnoti.sock
```

### npm Scripts
```json
{
  "scripts": {
    "build": "webpack && echo '{\"title\":\"🎉 构建完成\",\"message\":\"Webpack 构建成功！\",\"type\":\"celebration\"}' | nc -U /tmp/notchnoti.sock",
    "test": "jest && echo '{\"title\":\"✅ 测试通过\",\"message\":\"所有测试用例通过\",\"type\":\"success\",\"priority\":2}' | nc -U /tmp/notchnoti.sock"
  }
}
```

### VS Code / Cursor 任务
```json
{
  "tasks": [{
    "label": "Build with Notification",
    "command": "npm run build && echo '{\"title\":\"✅ 完成\",\"message\":\"构建成功！看勾号动画\",\"type\":\"success\",\"priority\":2}' | nc -U /tmp/notchnoti.sock"
  }, {
    "label": "Deploy with Progress",
    "command": "deploy.sh && echo '{\"title\":\"🔄 部署中\",\"message\":\"正在同步到服务器...\",\"type\":\"sync\"}' | nc -U /tmp/notchnoti.sock"
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
- **Network.framework** - Unix Socket 通信
- **Combine** - 响应式编程
- **Swift 5.9** - 现代 Swift 特性
- **Metal** - GPU 加速动画渲染
- **NSHapticFeedbackManager** - 触控板震动反馈

## 📋 系统要求

- macOS 13.0 (Ventura) 或更高版本
- 带刘海屏的 MacBook Pro (2021+) 或 MacBook Air (2022+)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

主要改进方向：
- [x] Unix Socket 通信支持
- [x] Claude Code 自动配置
- [x] 多语言支持（中英文）
- [x] 触感反馈
- [x] 通知声音
- [ ] 双向交互支持
- [ ] 更多通知样式
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