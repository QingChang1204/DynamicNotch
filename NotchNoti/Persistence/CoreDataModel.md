# CoreData Model Definition

## 手动创建步骤

由于无法通过命令行创建 `.xcdatamodeld` 文件,请在 Xcode 中手动创建:

### 1. 创建数据模型文件

1. 在 Xcode 中,File → New → File → Core Data → Data Model
2. 命名为 `NotchNoti.xcdatamodeld`
3. 保存到 `NotchNoti/Persistence/` 目录

### 2. 创建 NotificationEntity

**Entity Name**: `NotificationEntity`

**Attributes**:
- `id`: UUID (indexed)
- `timestamp`: Date (indexed)
- `title`: String
- `message`: String
- `typeRawValue`: String (indexed)
- `priorityRawValue`: Integer 16
- `icon`: String (Optional)
- `metadataJSON`: Binary Data (Optional)
- `userChoice`: String (Optional)

**Relationships**:
- `actions`: To-Many → NotificationActionEntity, Delete Rule: Cascade

**Indexes**:
- `timestamp` (降序)
- `typeRawValue`
- Compound: `typeRawValue + timestamp`

---

### 3. 创建 NotificationActionEntity

**Entity Name**: `NotificationActionEntity`

**Attributes**:
- `id`: UUID
- `label`: String
- `action`: String
- `styleRawValue`: String

**Relationships**:
- `notification`: To-One → NotificationEntity, Delete Rule: Nullify

---

### 4. 创建 WorkSessionEntity

**Entity Name**: `WorkSessionEntity`

**Attributes**:
- `id`: UUID (indexed)
- `projectName`: String (indexed)
- `startTime`: Date (indexed)
- `endTime`: Date (Optional)

**Relationships**:
- `activities`: To-Many → ActivityEntity, Delete Rule: Cascade

**Indexes**:
- `startTime` (降序)
- `projectName`
- Compound: `projectName + startTime`

---

### 5. 创建 ActivityEntity

**Entity Name**: `ActivityEntity`

**Attributes**:
- `id`: UUID
- `timestamp`: Date
- `typeRawValue`: String
- `tool`: String
- `duration`: Double

**Relationships**:
- `session`: To-One → WorkSessionEntity, Delete Rule: Nullify

---

## 配置选项

在 Model Inspector 中配置:

### NotificationEntity

- **Class**: `NotificationEntity`
- **Codegen**: `Manual/None` (我们已经手动创建了Swift文件)

### WorkSessionEntity

- **Class**: `WorkSessionEntity`
- **Codegen**: `Manual/None`

### ActivityEntity

- **Class**: `ActivityEntity`
- **Codegen**: `Manual/None`

### NotificationActionEntity

- **Class**: `NotificationActionEntity`
- **Codegen**: `Manual/None`

---

## 验证步骤

创建完成后,确保:

1. ✅ 所有 Entity 的 Class 名称与 Swift 文件匹配
2. ✅ Codegen 设置为 `Manual/None`
3. ✅ 索引已创建 (提升查询性能)
4. ✅ 关系的 Delete Rule 正确设置
5. ✅ 在 Xcode Project Navigator 中,`.xcdatamodeld` 显示在 `Persistence/` 分组下

---

## 替代方案 (临时)

如果暂时无法创建 `.xcdatamodeld`,可以先注释掉 `CoreDataStack.swift` 中的模型加载代码,使用内存模式测试其他功能。待手动创建模型后再启用。
