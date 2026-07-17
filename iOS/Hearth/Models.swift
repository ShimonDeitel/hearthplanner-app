import Foundation
import SwiftData

// MARK: - Kid

@Model
final class Kid {
    var name: String
    var gradeLevel: String
    /// Hue in degrees 0-360, used to tint everything belonging to this kid.
    var hue: Double
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SubjectItem.kid)
    var subjects: [SubjectItem] = []

    @Relationship(deleteRule: .cascade, inverse: \Lesson.kid)
    var lessons: [Lesson] = []

    init(name: String, gradeLevel: String = "", hue: Double = 32) {
        self.name = name
        self.gradeLevel = gradeLevel
        self.hue = hue
        self.createdAt = Date()
    }
}

// MARK: - SubjectItem

@Model
final class SubjectItem {
    var name: String
    var symbolName: String
    /// Weekly target in hours (e.g. 3.5).
    var weeklyTargetHours: Double
    var createdAt: Date

    var kid: Kid?

    @Relationship(deleteRule: .cascade, inverse: \Lesson.subject)
    var lessons: [Lesson] = []

    @Relationship(deleteRule: .cascade, inverse: \ResourceItem.subject)
    var resources: [ResourceItem] = []

    init(name: String, symbolName: String = "book.closed.fill", weeklyTargetHours: Double = 3, kid: Kid? = nil) {
        self.name = name
        self.symbolName = symbolName
        self.weeklyTargetHours = weeklyTargetHours
        self.createdAt = Date()
        self.kid = kid
    }
}

// MARK: - Lesson

@Model
final class Lesson {
    /// Normalized to start of day.
    var date: Date
    var title: String
    var details: String
    var materials: String
    var estimatedMinutes: Int
    var isDone: Bool
    var completedAt: Date?
    var createdAt: Date

    var kid: Kid?
    var subject: SubjectItem?

    init(date: Date,
         title: String,
         details: String = "",
         materials: String = "",
         estimatedMinutes: Int = 30,
         kid: Kid? = nil,
         subject: SubjectItem? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.title = title
        self.details = details
        self.materials = materials
        self.estimatedMinutes = estimatedMinutes
        self.isDone = false
        self.completedAt = nil
        self.createdAt = Date()
        self.kid = kid
        self.subject = subject
    }
}

// MARK: - ResourceItem

enum ResourceStatus: String, Codable, CaseIterable {
    case notStarted = "Not started"
    case inProgress = "In progress"
    case done = "Done"

    var symbolName: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        }
    }

    var next: ResourceStatus {
        switch self {
        case .notStarted: return .inProgress
        case .inProgress: return .done
        case .done: return .notStarted
        }
    }
}

@Model
final class ResourceItem {
    var title: String
    var note: String
    var statusRaw: String
    var createdAt: Date

    var subject: SubjectItem?

    var status: ResourceStatus {
        get { ResourceStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }

    init(title: String, note: String = "", status: ResourceStatus = .notStarted, subject: SubjectItem? = nil) {
        self.title = title
        self.note = note
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.subject = subject
    }
}

// MARK: - AppConfig (single row of app-level settings)

@Model
final class AppConfig {
    var schoolYearStart: Date
    var schoolYearEnd: Date
    var requiredDays: Int

    init(schoolYearStart: Date, schoolYearEnd: Date, requiredDays: Int = 180) {
        self.schoolYearStart = schoolYearStart
        self.schoolYearEnd = schoolYearEnd
        self.requiredDays = requiredDays
    }

    /// Fetches the single config row, creating a sensible default if missing.
    static func fetchOrCreate(in context: ModelContext) -> AppConfig {
        let descriptor = FetchDescriptor<AppConfig>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let cal = Calendar.current
        let now = Date()
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)
        // School year runs Aug 15 -> Jun 15. If we are past June, this year's August starts it.
        let startYear = month >= 7 ? year : year - 1
        let start = cal.date(from: DateComponents(year: startYear, month: 8, day: 15)) ?? now
        let end = cal.date(from: DateComponents(year: startYear + 1, month: 6, day: 15)) ?? now
        let config = AppConfig(schoolYearStart: start, schoolYearEnd: end, requiredDays: 180)
        context.insert(config)
        return config
    }
}
