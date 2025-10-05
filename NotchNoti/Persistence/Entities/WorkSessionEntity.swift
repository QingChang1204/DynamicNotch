//
//  WorkSessionEntity.swift
//  NotchNoti
//
//  工作会话 CoreData 实体
//  记录开发会话的统计数据和活动
//

import CoreData
import Foundation

@objc(WorkSessionEntity)
public class WorkSessionEntity: NSManagedObject {
    // MARK: - Properties

    @NSManaged public var id: UUID
    @NSManaged public var projectName: String
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?

    // Relations
    @NSManaged public var activities: NSSet?  // ActivityEntity

    // MARK: - Computed Properties

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var totalActivities: Int {
        (activities as? Set<ActivityEntity>)?.count ?? 0
    }

    var pace: Double {
        guard duration > 0 else { return 0 }
        return Double(totalActivities) / (duration / 60.0)
    }

    var intensity: WorkSession.Intensity {
        if pace > 8 { return .intense }
        if pace > 4 { return .focused }
        if pace > 1 { return .steady }
        return .light
    }

    var activityDistribution: [ActivityType: Int] {
        guard let activities = activities as? Set<ActivityEntity> else { return [:] }
        return Dictionary(grouping: activities, by: { $0.activityType })
            .mapValues { $0.count }
    }

    var workMode: WorkSession.WorkMode {
        let dist = activityDistribution
        let writeOps = (dist[.edit] ?? 0) + (dist[.write] ?? 0)
        let readOps = (dist[.read] ?? 0) + (dist[.grep] ?? 0) + (dist[.glob] ?? 0)
        let execOps = dist[.bash] ?? 0

        if writeOps > readOps && writeOps > execOps {
            return .writing
        } else if readOps > writeOps * 2 {
            return .researching
        } else if execOps > totalActivities / 3 {
            return .debugging
        } else if writeOps > 0 && readOps > 0 {
            return .developing
        }
        return .exploring
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        startTime = Date()
    }
}

// MARK: - Core Data Helpers

extension WorkSessionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkSessionEntity> {
        return NSFetchRequest<WorkSessionEntity>(entityName: "WorkSessionEntity")
    }

    @discardableResult
    static func create(
        projectName: String,
        in context: NSManagedObjectContext
    ) -> WorkSessionEntity {
        let entity = WorkSessionEntity(context: context)
        entity.projectName = projectName
        return entity
    }

    func toModel() -> WorkSession {
        let activityModels = (activities as? Set<ActivityEntity>)?
            .map { $0.toModel() }
            .sorted { $0.timestamp < $1.timestamp } ?? []

        return WorkSession(
            id: id,
            projectName: projectName,
            startTime: startTime,
            endTime: endTime,
            activities: activityModels
        )
    }

    func addActivity(_ activity: Activity, in context: NSManagedObjectContext) {
        let activityEntity = ActivityEntity.create(from: activity, in: context)
        let mutableActivities = (activities as? NSMutableSet) ?? NSMutableSet()
        mutableActivities.add(activityEntity)
        activities = mutableActivities
    }
}

// MARK: - Activity Entity

@objc(ActivityEntity)
public class ActivityEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var typeRawValue: String
    @NSManaged public var tool: String
    @NSManaged public var duration: TimeInterval

    @NSManaged public var session: WorkSessionEntity?

    var activityType: ActivityType {
        get { ActivityType(rawValue: typeRawValue) ?? .other }
        set { typeRawValue = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        timestamp = Date()
    }

    static func create(
        from activity: Activity,
        in context: NSManagedObjectContext
    ) -> ActivityEntity {
        let entity = ActivityEntity(context: context)
        entity.id = activity.id
        entity.timestamp = activity.timestamp
        entity.activityType = activity.type
        entity.tool = activity.tool
        entity.duration = activity.duration
        return entity
    }

    func toModel() -> Activity {
        Activity(
            id: id,
            timestamp: timestamp,
            type: activityType,
            tool: tool,
            duration: duration
        )
    }
}

// MARK: - Fetch Requests

extension WorkSessionEntity {
    /// 最近的会话
    static func recentSessions(limit: Int = 20) -> NSFetchRequest<WorkSessionEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        request.fetchLimit = limit
        return request
    }

    /// 今日会话
    static func todaySessions() -> NSFetchRequest<WorkSessionEntity> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let request = fetchRequest()
        request.predicate = NSPredicate(format: "startTime >= %@", startOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return request
    }

    /// 按项目查询
    static func sessions(forProject project: String) -> NSFetchRequest<WorkSessionEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "projectName == %@", project)
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return request
    }

    /// 时间范围查询
    static func sessions(from: Date, to: Date) -> NSFetchRequest<WorkSessionEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime <= %@",
            from as NSDate,
            to as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return request
    }
}

// MARK: - Model Extensions

extension Activity {
    init(
        id: UUID,
        timestamp: Date,
        type: ActivityType,
        tool: String,
        duration: TimeInterval
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.tool = tool
        self.duration = duration
    }
}

extension WorkSession {
    init(
        id: UUID,
        projectName: String,
        startTime: Date,
        endTime: Date?,
        activities: [Activity]
    ) {
        self.id = id
        self.projectName = projectName
        self.startTime = startTime
        self.endTime = endTime
        self.activities = activities
    }
}
