# NotchNoti 统计功能说明

## 🎯 新增功能概览

为 NotchNoti 添加了完整的智能统计系统,包括:
1. ✅ **智能通知分组与统计**
2. ✅ **性能指标可视化**
3. ✅ **错误追踪与调试辅助**

## 📊 功能详情

### 1. 会话统计 (Session Statistics)

**功能描述**: 实时追踪每个 Claude Code 会话的使用情况

**包含数据**:
- 会话时长
- 工具调用次数统计
- 成功/失败率
- 各工具平均执行时间
- 最常用工具 TOP5

**使用方式**:
1. 点击 notch 区域打开菜单
2. 点击"统计"按钮(📊图标)
3. 选择"当前会话"标签查看实时数据

### 2. 性能指标可视化

**功能描述**: 以直观的图表和数字展示性能数据

**包含指标**:
- ⏱️ 会话时长 - 实时显示当前会话运行时间
- 🔧 操作数 - 统计工具调用总次数
- ✅ 成功率 - 百分比显示操作成功率
- ⚡ 性能指标 - 各工具平均响应时间排行

**数据展示**:
- 会话概览卡片
- 工具使用排行榜
- 性能指标列表
- 彩色进度条可视化成功率

### 3. 错误历史追踪

**功能描述**: 自动记录和展示所有错误信息

**包含内容**:
- ❌ 错误工具名称
- 🕐 发生时间
- 📝 完整错误消息
- 🔗 相关上下文信息

**使用方式**:
1. 打开统计面板
2. 选择"错误历史"标签
3. 查看当前会话所有错误记录

### 4. 总览统计

**功能描述**: 历史会话数据汇总分析

**包含数据**:
- 📈 总会话数
- 🎯 平均成功率
- 📅 今日统计
- 🔧 工具使用统计 (所有会话)

## 🏗️ 技术实现

### 数据模型

**新增文件**: `NotchNoti/StatisticsModel.swift`

```swift
// 会话统计数据
struct SessionStats {
    let sessionId: String
    let projectName: String
    let startTime: Date
    var toolUsage: [String: ToolStats]
    var totalOperations: Int
    var errorCount: Int
    var errors: [ErrorRecord]
}

// 工具统计数据
struct ToolStats {
    var count: Int
    var successCount: Int
    var failureCount: Int
    var totalDuration: TimeInterval
    var averageDuration: TimeInterval
    var successRate: Double
}

// 错误记录
struct ErrorRecord {
    let toolName: String
    let errorMessage: String
    let timestamp: Date
    let context: String?
}
```

### 统计管理器

**StatisticsManager**: 单例模式,负责:
- 会话生命周期管理
- 工具使用数据收集
- 错误记录存储
- 历史数据持久化 (UserDefaults)
- LRU缓存策略 (最多保存20个会话)

### UI 视图

**新增文件**: `NotchNoti/NotchStatsView.swift`

**视图结构**:
```
NotchStatsView
├── CurrentSessionView (当前会话)
│   ├── 会话概览卡片
│   ├── 工具使用排行
│   └── 性能指标列表
├── ErrorHistoryView (错误历史)
│   └── 错误卡片列表
└── OverviewView (总览)
    ├── 总体统计
    ├── 今日统计
    └── 工具使用统计
```

### Hook 集成

**Rust Hook 更新**:
- 添加 `session_start_time` 追踪会话时长
- 在 metadata 中传递 `event_type`, `session_id`, `duration` 等信息
- 错误通知包含 `tool_error` 事件类型和详细错误信息

**示例 metadata**:
```json
{
  "source": "claude-code",
  "project": "DynamicNotch",
  "session_duration": "120.5",
  "event_type": "tool_error",
  "tool_name": "Bash",
  "error_message": "Command failed with exit code 1"
}
```

### 数据流

```
Rust Hook (统计收集)
    ↓ (通过 Unix Socket 发送)
UnixSocketServerSimple (接收通知)
    ↓ (调用 processStatistics)
StatisticsManager (数据处理)
    ↓ (更新 @Published 属性)
NotchStatsView (UI 更新)
```

## 📝 使用示例

### 场景 1: 查看当前会话性能

1. 在使用 Claude Code 时,打开 notch
2. 点击"统计"按钮
3. 查看实时数据:
   - 会话已运行 5:30
   - 执行了 42 个操作
   - 成功率 95.2%
   - Read 工具使用最频繁 (15次)
   - Bash 平均耗时最长 (2.3s)

### 场景 2: 调试错误

1. 发现某个操作失败
2. 打开统计面板 → 错误历史
3. 查看详细错误信息:
   ```
   ❌ Bash                    14:23:15
   Command 'npm test' failed with exit code 1
   ```
4. 根据错误信息进行调试

### 场景 3: 分析历史数据

1. 打开统计面板 → 总览
2. 查看数据:
   - 今天完成了 8 个会话
   - 总共执行了 256 个操作
   - Edit 工具使用最多 (78次)
   - 平均成功率 94.3%

## 🔧 配置选项

### 数据持久化

- 自动保存到 UserDefaults
- 存储键: `com.notchnoti.sessionStats`
- 最多保存 20 个会话 (LRU策略)
- 最多保存 50 条通知历史

### 性能优化

- 统计数据仅在需要时计算
- UI 使用 @Published 实现响应式更新
- 后台队列处理 Socket 数据
- 主线程仅用于 UI 更新

## 📦 新增文件列表

1. `NotchNoti/StatisticsModel.swift` - 数据模型和管理器
2. `NotchNoti/NotchStatsView.swift` - 统计视图UI
3. 更新: `NotchNoti/NotchViewModel.swift` - 添加 stats 内容类型
4. 更新: `NotchNoti/NotchContentView.swift` - 集成统计视图
5. 更新: `NotchNoti/NotchMenuView.swift` - 添加统计按钮
6. 更新: `NotchNoti/UnixSocketServerSimple.swift` - 处理统计数据
7. 更新: `.claude/hooks/rust-hook/src/main.rs` - 收集统计信息

## 🚀 后续优化建议

### 已实现的功能 (1, 3, 4)
- ✅ 智能通知分组与统计
- ✅ 性能指标可视化
- ✅ 错误追踪与调试辅助

### 待实现的功能 (2, 5)

**2. 通知交互增强**:
- [ ] 点击 Edit/Write 通知打开文件
- [ ] 点击 Bash 错误查看完整日志
- [ ] 支持通知操作按钮

**5. 上下文感知通知**:
- [ ] Git 操作时显示当前分支
- [ ] 编辑文件时显示 git 状态
- [ ] 测试运行时显示结果摘要

## 📚 开发者文档

### 如何添加新的统计指标

1. 在 `SessionStats` 中添加新字段
2. 在 `StatisticsManager` 中添加记录方法
3. 在 Rust hook 中收集数据并传递到 metadata
4. 在 `processStatistics` 中处理新数据
5. 在 UI 视图中展示新指标

### 如何自定义统计视图

编辑 `NotchStatsView.swift`,可以:
- 修改卡片样式
- 添加新的统计标签
- 自定义数据展示格式
- 添加图表可视化

## 🎉 总结

新增的统计系统为 NotchNoti 带来了:
- 📊 **可见性**: 实时了解 Claude Code 使用情况
- 🎯 **性能追踪**: 识别慢速操作和瓶颈
- 🐛 **调试辅助**: 快速定位和分析错误
- 📈 **数据洞察**: 历史数据分析优化工作流

所有代码已完成,现在只需要在 Xcode 中添加新文件到项目,然后重新构建即可使用!

---

**创建日期**: 2025-10-03
**版本**: 1.0.0
**作者**: Claude Code Assistant
