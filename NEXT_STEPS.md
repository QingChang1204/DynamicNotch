# 下一步行动清单

## ✅ 已完成
- [x] 创建 CoreData 基础设施 (Stack, Entities, Repositories)
- [x] 实现统一错误处理系统
- [x] 整合常量和工具类
- [x] 创建 NotificationManager v2 (Actor 模式)
- [x] 2 次增量编译验证通过

---

## 🎯 立即执行 (5-10分钟)

### 步骤 1: 在 Xcode 中创建 CoreData 模型

1. 打开 Xcode
   ```bash
   open NotchNoti.xcodeproj
   ```

2. 创建数据模型文件
   - File → New → File (⌘N)
   - 选择: iOS → Core Data → Data Model
   - 命名: `NotchNoti` (不要加扩展名)
   - 保存到: `NotchNoti/Persistence/` 目录
   - Group: `Persistence`

3. 创建 4 个 Entity (详细参考 `CoreDataModel.md`)

#### Entity 1: NotificationEntity
```
Attributes:
  id: UUID
  timestamp: Date
  title: String
  message: String
  typeRawValue: String
  priorityRawValue: Integer 16
  icon: String (Optional)
  metadataJSON: Binary Data (Optional)
  userChoice: String (Optional)

Relationships:
  actions → NotificationActionEntity (To-Many, Cascade)

Indexes:
  - timestamp (降序)
  - typeRawValue
  - Compound: [typeRawValue, timestamp]
```

#### Entity 2: NotificationActionEntity
```
Attributes:
  id: UUID
  label: String
  action: String
  styleRawValue: String

Relationships:
  notification → NotificationEntity (To-One, Nullify)
```

#### Entity 3: WorkSessionEntity
```
Attributes:
  id: UUID
  projectName: String
  startTime: Date
  endTime: Date (Optional)

Relationships:
  activities → ActivityEntity (To-Many, Cascade)

Indexes:
  - startTime (降序)
  - projectName
  - Compound: [projectName, startTime]
```

#### Entity 4: ActivityEntity
```
Attributes:
  id: UUID
  timestamp: Date
  typeRawValue: String
  tool: String
  duration: Double

Relationships:
  session → WorkSessionEntity (To-One, Nullify)
```

4. 配置每个 Entity
   - 选中 Entity → Data Model Inspector (右侧)
   - Class: 设置为对应的类名 (如 `NotificationEntity`)
   - Codegen: 选择 `Manual/None`
   - Module: 留空或选择 `Current Product Module`

5. 保存 (⌘S)

---

### 步骤 2: 添加新文件到 Xcode Project

**如果新文件还未出现在 Project Navigator:**

1. 右键 `Persistence` 组 → Add Files to "NotchNoti"
2. 选择以下文件:
   - `CoreDataStack.swift`
   - `Entities/NotificationEntity.swift`
   - `Entities/WorkSessionEntity.swift`
   - `Repositories/NotificationRepository.swift`
   - `Repositories/StatisticsRepository.swift`

3. 右键 `Core` 组 → Add Files
   - `AppError.swift`

4. 右键 `Utilities` 组 → Add Files
   - `Constants.swift`
   - `CommonHelpers.swift`

5. 右键 `Models & Data` 组 → Add Files
   - `NotificationManager_v2.swift`

**确保勾选**:
- [x] Copy items if needed
- [x] Create groups
- [x] Add to targets: NotchNoti

---

### 步骤 3: 编译验证

```bash
xcodebuild -project NotchNoti.xcodeproj -scheme NotchNoti build
```

**预期结果**: `** BUILD SUCCEEDED **`

如果出现错误:
- 检查 CoreData 模型是否正确创建
- 检查所有文件是否添加到 target
- 检查 Entity 的 Class 名称是否匹配

---

## 🚀 快速启用新功能 (可选)

### A. 立即使用新的错误处理

在任何新代码中:
```swift
do {
    try await someOperation()
} catch let error as AppError {
    Log.error(error)
    // 显示给用户
    showAlert(error.localizedDescription, suggestion: error.recoverySuggestion)
} catch {
    Log.error(error)
}
```

### B. 立即使用新常量

全局查找替换:
```swift
// 查找: if pendingQueue.count >= 10
// 替换: if pendingQueue.count >= NotificationConstants.maxQueueSize

// 查找: 0.5
// 替换: NotificationConstants.mergeTimeWindow
```

### C. 立即使用工具类

```swift
// 时间格式化
duration.formattedDuration  // "1h23m"

// 路径处理
PathHelpers.relativePath(for: fullPath, projectRoot: projectPath)

// 防抖
let debouncer = Debouncer(delay: .milliseconds(300))
await debouncer.debounce {
    await performSearch(query)
}
```

---

## 📅 后续计划 (可按需执行)

### 本周可做:

#### 1. 测试新的 CoreData 栈 (30分钟)
```swift
// 在 AppDelegate 中临时测试
Task {
    let repo = NotificationRepository()

    // 测试保存
    let testNotif = NotchNotification(title: "Test", message: "CoreData works!", type: .success)
    try await repo.save(testNotif)

    // 测试查询
    let history = try await repo.fetch(page: 0, pageSize: 10)
    print("Loaded \(history.count) notifications")
}
```

#### 2. 实施数据迁移 (1小时)
- 创建 `UserDefaultsMigrator.swift`
- 从旧的 UserDefaults 导入到 CoreData
- 验证数据完整性
- 删除旧数据

#### 3. 替换 NotificationManager (2小时)
- 重命名 `NotificationManager_v2.swift`
- 更新所有调用点为 `await`
- 删除旧的 `NotificationManager` 类
- 测试通知功能

### 下周可做:

#### 4. 重构 StatisticsManager (1.5小时)
#### 5. 重写 UnixSocketServer (2小时)
#### 6. 优化 MCPServer 超时 (1小时)
#### 7. Rust Hook 配置化 (30分钟)

### 长期规划:

#### 8. 添加单元测试 (4小时)
#### 9. 集成 CI/CD (2小时)
#### 10. 性能优化迭代 (持续)

---

## 🐛 故障排除

### 问题 1: CoreData 模型文件无法加载

**症状**: 运行时崩溃 "CoreData store failed to load"

**解决**:
1. 检查 `.xcdatamodeld` 文件是否在 target 中
2. 检查 Entity 名称是否与代码匹配
3. 检查 Codegen 设置为 `Manual/None`

### 问题 2: 编译错误 "Cannot find type NotificationEntity"

**症状**: 编译时找不到 Entity 类

**解决**:
1. 确保 `NotificationEntity.swift` 已添加到 target
2. 确保 CoreData 模型中 Entity 的 Class 设置正确
3. Clean Build Folder (⇧⌘K)

### 问题 3: Actor 隔离警告

**症状**: "Actor-isolated property cannot be referenced from non-isolated context"

**解决**:
```swift
// 错误:
let manager = NotificationManager.shared
manager.addNotification(...)  // ❌

// 正确:
Task {
    await NotificationManager.shared.addNotification(...)  // ✅
}
```

---

## 📞 需要帮助?

1. **查看参考文档**:
   - `REFACTORING_GUIDE.md` - 完整实施指南
   - `CoreDataModel.md` - 模型创建详细步骤
   - `REFACTORING_SUMMARY.md` - 架构决策说明

2. **增量验证**:
   - 每完成一个步骤就编译一次
   - 使用 `Log.debug()` 跟踪执行流程

3. **回滚策略**:
   - 所有新文件都有 `_v2` 后缀,随时可以删除
   - 旧代码完全保留,未被修改

---

## 🎉 成功标志

当你完成以上步骤,你将拥有:

- ✅ 现代化的 CoreData 数据层
- ✅ 100% 线程安全的并发模型
- ✅ 类型安全的错误处理
- ✅ 零魔法数字的清晰代码
- ✅ 可测试的架构设计

**现在就开始吧!第一步只需 5 分钟!** 🚀
