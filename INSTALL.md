# NotchDrop 安装指南

## 系统要求
- macOS 13.0 (Ventura) 或更高版本
- 带刘海屏的 MacBook Pro/Air

## 安装步骤

### 方法一：使用 DMG 安装包（推荐）

1. 下载 `NotchDrop-1.0.0.dmg`
2. 双击打开 DMG 文件
3. 将 `NotchNotifier.app` 拖拽到 `Applications` 文件夹
4. 弹出 DMG 磁盘镜像

### 方法二：从源码构建

```bash
# 克隆仓库
git clone https://github.com/QingChang1204/DynamicNotch.git
cd DynamicNotch

# 构建应用
xcodebuild -scheme NotchDrop -configuration Release build

# 或使用打包脚本
./build-dmg.sh
```

## 首次运行

### 解决 "无法打开" 问题

由于应用未经 Apple 公证，首次运行可能会遇到安全提示：

1. **右键点击** NotchNotifier.app
2. 选择 **"打开"**
3. 在弹出的对话框中点击 **"打开"**

或者：

1. 打开 **系统偏好设置** > **隐私与安全性**
2. 找到 "已阻止使用NotchNotifier"
3. 点击 **"仍要打开"**

## 功能特性

### 🔔 通知系统
- 在刘海区域显示通知
- 支持 4 个优先级级别
- 自动合并相似通知
- 通知队列管理

### 🎨 视觉效果
- 进入/退出动画
- 紧急通知脉冲效果
- 深色/浅色模式自适应
- 渐变背景和阴影

### 🔌 API 接口
发送通知到 `http://localhost:9876/notify`：

```bash
curl -X POST http://localhost:9876/notify \
  -H "Content-Type: application/json" \
  -d '{
    "title": "测试通知",
    "message": "这是一条测试消息",
    "type": "info",
    "priority": 1
  }'
```

参数说明：
- `title`: 通知标题
- `message`: 通知内容
- `type`: 类型 (info/success/warning/error/hook/tool_use/progress)
- `priority`: 优先级 (0=低, 1=普通, 2=高, 3=紧急)

## Claude Code 集成

### 配置 Hooks

1. 复制配置文件到项目：
```bash
cp -r /path/to/NotchDrop/.claude /your/project/
```

2. 配置会自动发送通知：
- 文件修改前警告
- 需要确认时提醒
- 任务完成通知

### 选择通知级别

- **标准版**: `.claude/settings.json`
- **专注版**: `.claude/settings-focused.json`（更少通知）

## 常见问题

### Q: 应用无法启动？
A: 确保系统版本为 macOS 13.0+，并按照"首次运行"步骤操作。

### Q: 通知不显示？
A: 检查应用是否在运行，端口 9876 是否被占用。

### Q: 如何关闭应用？
A: 点击刘海区域，选择菜单中的退出选项。

## 反馈与支持

- GitHub: https://github.com/QingChang1204/DynamicNotch
- 问题反馈: [提交 Issue](https://github.com/QingChang1204/DynamicNotch/issues)

## 开源协议

MIT License