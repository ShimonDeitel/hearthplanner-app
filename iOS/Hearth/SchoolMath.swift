import Foundation

/// A plain-value snapshot of a lesson, so all roll-up math is pure and unit-testable
/// without touching SwiftData.
struct LessonFact: Equatable {
    var date: Date
    var kidName: String
    var subjectName: String
    var title: String
    var minutes: Int
    var isDone: Bool
}

/// A lesson-to-be, produced by week copying.
struct LessonTemplate: Equatable {
    var date: Date
    var kidName: String
    var subjectName: String
    var title: String
    var details: String
    var materials: String
    var minutes: Int
}

/// One subject line inside a report.
struct SubjectHours: Equatable {
    var subjectName: String
    var hours: Double
}

/// A finished, ready-to-render attendance and hours report for one kid.
struct AttendanceReport: Equatable {
    var kidName: String
    var gradeLevel: String
    var rangeLabel: String
    var daysAttended: Int
    var requiredDays: Int
    var totalHours: Double
    var subjects: [SubjectHours]
}

enum SchoolMath {

    // MARK: - Hours roll-ups

    /// Total completed minutes across the given facts.
    static func completedMinutes(_ facts: [LessonFact]) -> Int {
        facts.filter { $0.isDone }.reduce(0) { $0 + $1.minutes }
    }

    /// Completed hours, rounded to 2 decimal places.
    static func completedHours(_ facts: [LessonFact]) -> Double {
        (Double(completedMinutes(facts)) / 60.0 * 100).rounded() / 100
    }

    /// Completed hours grouped by subject, sorted by subject name.
    static func hoursBySubject(_ facts: [LessonFact]) -> [SubjectHours] {
        var buckets: [String: Int] = [:]
        for fact in facts where fact.isDone {
            buckets[fact.subjectName, default: 0] += fact.minutes
        }
        return buckets
            .map { SubjectHours(subjectName: $0.key, hours: (Double($0.value) / 60.0 * 100).rounded() / 100) }
            .sorted { $0.subjectName < $1.subjectName }
    }

    // MARK: - Attendance

    /// Number of distinct calendar days that have at least one completed lesson.
    static func daysAttended(_ facts: [LessonFact], calendar: Calendar = .current) -> Int {
        let days = Set(facts.filter { $0.isDone }.map { calendar.startOfDay(for: $0.date) })
        return days.count
    }

    /// Facts restricted to a date interval (inclusive of start, exclusive of end).
    static func facts(_ facts: [LessonFact], in interval: DateInterval) -> [LessonFact] {
        facts.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    // MARK: - Streaks

    /// Consecutive-day learning streak ending today or yesterday.
    /// Weekend days without lessons do not break the streak.
    static func streak(_ facts: [LessonFact], today: Date, calendar: Calendar = .current) -> Int {
        let doneDays = Set(facts.filter { $0.isDone }.map { calendar.startOfDay(for: $0.date) })
        guard !doneDays.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: today)
        // A streak may still be alive if today has no lesson yet: start from yesterday.
        if !doneDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while true {
            if doneDays.contains(cursor) {
                count += 1
            } else if calendar.isDateInWeekend(cursor) {
                // excused, keep walking back
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    // MARK: - Week math

    /// Start of the week containing `date` (uses the calendar's own first weekday).
    static func weekStart(containing date: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    /// The seven days of the week starting at `weekStart`.
    static func weekDays(from weekStart: Date, calendar: Calendar = .current) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    // MARK: - Copy last week

    /// Builds templates that reproduce last week's lessons in the target week,
    /// shifted forward exactly seven days, skipping any lesson that would collide
    /// with an existing lesson (same kid, subject, title and date).
    static func copyWeekPlan(previousWeekLessons: [LessonTemplate],
                             existingTargetWeek: [LessonTemplate],
                             calendar: Calendar = .current) -> [LessonTemplate] {
        var plan: [LessonTemplate] = []
        for lesson in previousWeekLessons {
            guard let shifted = calendar.date(byAdding: .day, value: 7, to: lesson.date) else { continue }
            let candidate = LessonTemplate(date: calendar.startOfDay(for: shifted),
                                           kidName: lesson.kidName,
                                           subjectName: lesson.subjectName,
                                           title: lesson.title,
                                           details: lesson.details,
                                           materials: lesson.materials,
                                           minutes: lesson.minutes)
            let collides = existingTargetWeek.contains {
                $0.kidName == candidate.kidName
                    && $0.subjectName == candidate.subjectName
                    && $0.title == candidate.title
                    && calendar.isDate($0.date, inSameDayAs: candidate.date)
            }
            if !collides {
                plan.append(candidate)
            }
        }
        return plan
    }

    // MARK: - Report assembly

    /// Assembles a state-reporting summary for one kid over a date interval.
    static func buildReport(kidName: String,
                            gradeLevel: String,
                            facts: [LessonFact],
                            interval: DateInterval,
                            rangeLabel: String,
                            requiredDays: Int,
                            calendar: Calendar = .current) -> AttendanceReport {
        let kidFacts = self.facts(facts.filter { $0.kidName == kidName }, in: interval)
        return AttendanceReport(kidName: kidName,
                                gradeLevel: gradeLevel,
                                rangeLabel: rangeLabel,
                                daysAttended: daysAttended(kidFacts, calendar: calendar),
                                requiredDays: requiredDays,
                                totalHours: completedHours(kidFacts),
                                subjects: hoursBySubject(kidFacts))
    }

    /// CSV for one or more kid reports. First column block is the summary,
    /// followed by one row per subject.
    static func csv(for reports: [AttendanceReport]) -> String {
        var lines: [String] = []
        lines.append("Student,Grade,Period,Days Attended,Required Days,Total Hours,Subject,Subject Hours")
        for report in reports {
            if report.subjects.isEmpty {
                lines.append([csvField(report.kidName),
                              csvField(report.gradeLevel),
                              csvField(report.rangeLabel),
                              "\(report.daysAttended)",
                              "\(report.requiredDays)",
                              String(format: "%.2f", report.totalHours),
                              "", ""].joined(separator: ","))
            }
            for subject in report.subjects {
                lines.append([csvField(report.kidName),
                              csvField(report.gradeLevel),
                              csvField(report.rangeLabel),
                              "\(report.daysAttended)",
                              "\(report.requiredDays)",
                              String(format: "%.2f", report.totalHours),
                              csvField(subject.subjectName),
                              String(format: "%.2f", subject.hours)].joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func csvField(_ raw: String) -> String {
        if raw.contains(",") || raw.contains("\"") || raw.contains("\n") {
            return "\"" + raw.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return raw
    }
}

// MARK: - Bridging SwiftData models to plain facts

extension Lesson {
    var fact: LessonFact {
        LessonFact(date: date,
                   kidName: kid?.name ?? "",
                   subjectName: subject?.name ?? "General",
                   title: title,
                   minutes: estimatedMinutes,
                   isDone: isDone)
    }

    var template: LessonTemplate {
        LessonTemplate(date: date,
                       kidName: kid?.name ?? "",
                       subjectName: subject?.name ?? "General",
                       title: title,
                       details: details,
                       materials: materials,
                       minutes: estimatedMinutes)
    }
}
