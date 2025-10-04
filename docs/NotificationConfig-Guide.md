# 消息配置系统使用指南

## 概述

NotchNoti 的消息配置系统提供了细粒度的通知控制，支持全局配置、类型配置和智能规则。

## 功能特性

### 1. 三层配置架构

```
全局配置（Global）
    ├── 全局开关：一键禁用所有通知
    ├── 默认行为：声音、触觉反馈
    ├── 智能合并：时间窗口配置
    └── 显示时长：默认显示时间

类型配置（Types）
    ├── 14种通知类型独立配置
    ├── 每种类型可设置：
    │   ├── 启用/禁用
    │   ├── 声音开关
    │   ├── 触觉反馈
    │   └── 自定义显示时长

静默规则（Rules）
    ├── 基于条件的智能过滤
    ├── 时间范围（如夜间免打扰）
    ├── 优先级过滤
    └── 内容匹配
```

### 2. 通知类型默认配置

| 类型 | 声音 | 触觉 | 默认时长 | 说明 |
|------|------|------|----------|------|
| **error** | ✅ | ✅ | 2.0s | 错误通知，重要且持久 |
| **security** | ✅ | ✅ | 2.0s | 安全警告，最高优先级 |
| **warning** | ✅ | ✅ | 1.5s | 警告信息 |
| **success** | ✅ | ❌ | 1.0s | 成功反馈，无触觉 |
| **celebration** | ✅ | ❌ | 1.0s | 庆祝动画 |
| **info** | ❌ | ❌ | 默认 | 信息通知，静默 |
| **hook** | ❌ | ❌ | 默认 | Hook事件，静默 |
| **toolUse** | ❌ | ❌ | 默认 | 工具使用，静默 |
| **progress** | ❌ | ❌ | 默认 | 进度更新，静默 |
| **其他** | ✅ | ✅ | 默认 | 其他类型 |

### 3. 静默规则系统

#### 预设规则模板

1. **夜间免打扰（22:00-07:00）**
   - 条件：时间范围 + 低优先级
   - 动作：完全静默

2. **工作时间静音（09:00-18:00）**
   - 条件：工作时间 + info/hook/toolUse类型
   - 动作：仅静音（仍显示）

3. **仅显示错误和警告**
   - 条件：非错误/警告类型
   - 动作：加入队列（不打断）

4. **专注模式**
   - 条件：无条件
   - 动作：全局静音

#### 自定义规则条件

- **类型匹配**：选择特定通知类型
- **优先级比较**：`==`, `<`, `<=`, `>`, `>=`
- **来源过滤**：根据 `metadata.source` 匹配
- **标题/内容包含**：文本搜索（不区分大小写）
- **时间范围**：24小时制，支持跨夜（如 22-7）

#### 规则动作

- **silence**：完全静默，不显示
- **muteSound**：仅静音，仍然显示和触觉
- **muteHaptic**：仅禁用触觉反馈
- **showInQueue**：加入队列，不打断当前通知

## 使用场景

### 场景 1：开发时减少干扰

```
配置：
1. 全局配置 → 默认时长改为 0.5s（更快消失）
2. 类型配置 → info/hook/toolUse 禁用声音
3. 静默规则 → 添加"仅显示错误"预设

效果：
- 开发过程中工具使用通知静默快速
- 错误和警告醒目提示
- 减少50%以上的干扰
```

### 场景 2：深夜编程

```
配置：
1. 静默规则 → 添加"夜间免打扰"预设
2. 类型配置 → error/security 保持声音
3. 全局配置 → 触觉反馈禁用

效果：
- 22:00-07:00 低优先级通知静默
- 关键错误仍然提醒
- 无触觉反馈不打扰他人
```

### 场景 3：演示/录屏

```
配置：
1. 全局配置 → 全局开关关闭
   或
2. 静默规则 → 添加"专注模式"预设

效果：
- 通知仍然记录到历史
- 不会在录屏中显示
- 统计数据正常收集
```

### 场景 4：只关心特定项目

```
配置：
1. 静默规则 → 自定义规则
   - 条件：source 不等于 "MyProject"
   - 动作：silence

效果：
- 只显示来自 MyProject 的通知
- 其他项目通知被过滤
```

## 技术细节

### 配置优先级

1. **全局开关**最高优先级
   - `globalEnabled = false` → 所有通知被过滤

2. **类型配置**次之
   - `TypeConfig.enabled = false` → 该类型被过滤

3. **静默规则**最后检查
   - 按添加顺序依次检查
   - 第一个匹配的规则生效

### 数据持久化

- **存储机制**：`@PublishedPersist` 自动保存到 `UserDefaults`
- **实时生效**：配置更改立即应用到新通知
- **向后兼容**：保留原有 `notificationSound`/`hapticFeedback` 设置

### 配置导出/导入

```swift
// 导出配置
if let data = NotificationConfigManager.shared.exportConfig() {
    // 保存到文件
    try? data.write(to: fileURL)
}

// 导入配置
if let data = try? Data(contentsOf: fileURL) {
    NotificationConfigManager.shared.importConfig(from: data)
}
```

## API 参考

### NotificationConfigManager

```swift
class NotificationConfigManager: ObservableObject {
    static let shared: NotificationConfigManager

    // 全局配置
    var globalEnabled: Bool
    var globalSoundEnabled: Bool
    var globalHapticEnabled: Bool
    var defaultDuration: TimeInterval
    var showInDoNotDisturb: Bool

    // 智能合并
    var smartMergeEnabled: Bool
    var mergeTimeWindow: TimeInterval

    // 类型配置
    func getTypeConfig(for type: NotificationType) -> TypeConfig
    func setTypeConfig(_ config: TypeConfig, for type: NotificationType)
    func resetTypeConfig(for type: NotificationType)

    // 静默规则
    var silentRules: [SilentRule]

    // 检查方法
    func shouldShowNotification(_ notification: NotchNotification) -> Bool
    func shouldPlaySound(for notification: NotchNotification) -> Bool
    func shouldPlayHaptic(for notification: NotchNotification) -> Bool
    func getDuration(for notification: NotchNotification) -> TimeInterval

    // 批量操作
    func resetAllConfigs()
    func exportConfig() -> Data?
    func importConfig(from data: Data) -> Bool
}
```

### TypeConfig

```swift
struct TypeConfig: Codable {
    var enabled: Bool
    var soundEnabled: Bool
    var hapticEnabled: Bool
    var customDuration: TimeInterval?
    var customSoundName: String?
}
```

### SilentRule

```swift
struct SilentRule: Codable, Identifiable {
    let id: UUID
    var name: String
    var enabled: Bool
    var conditions: [RuleCondition]
    var action: RuleAction

    enum RuleAction {
        case silence        // 完全静默
        case muteSound      // 只静音
        case muteHaptic     // 只禁用触觉
        case showInQueue    // 加入队列
    }
}
```

### RuleCondition

```swift
enum RuleCondition: Codable {
    case type([NotificationType])
    case priority(Priority, ComparisonOperator)
    case source(String)
    case titleContains(String)
    case messageContains(String)
    case timeRange(start: Int, end: Int)  // 24小时制
}
```

## UI 界面

### 访问路径

1. 点击刘海打开 NotchNoti
2. 点击底部"菜单"按钮（⋯）
3. 选择"消息配置"

### 三个配置页面

1. **全局页面**
   - 左侧：默认行为（声音、触觉、勿扰模式）
   - 中间：智能合并配置
   - 右侧：默认时长、重置按钮

2. **类型页面**
   - 左侧：14种通知类型列表
   - 右侧：选中类型的详细配置

3. **规则页面**
   - 规则列表（可删除）
   - 添加自定义规则
   - 预设规则快速添加

## 最佳实践

1. **从全局开始**
   - 先设置全局默认行为
   - 再针对特定类型微调

2. **合理使用规则**
   - 预设规则已覆盖常见场景
   - 自定义规则用于特殊需求

3. **定期检查**
   - 查看通知历史
   - 根据实际使用调整配置

4. **导出备份**
   - 重要配置导出保存
   - 多设备共享配置

## 故障排除

### 通知不显示

1. 检查全局开关是否启用
2. 检查类型配置是否禁用
3. 检查静默规则是否匹配

### 声音不播放

1. 检查全局声音开关
2. 检查类型声音配置
3. 检查系统音量设置

### 配置不生效

1. 确认配置已保存（自动）
2. 重启 NotchNoti 应用
3. 检查 UserDefaults 权限

## 未来功能

- [ ] 规则编辑器（图形化界面）
- [ ] 更多预设规则模板
- [ ] 按项目/来源的配置方案
- [ ] 配置方案快速切换
- [ ] 通知频率限制
- [ ] 智能学习用户习惯

---

**文档版本**：v1.0
**最后更新**：2025-10-05
**相关文件**：
- `NotificationConfig.swift`
- `NotchNotificationConfigView.swift`
- `NotificationModel.swift`
