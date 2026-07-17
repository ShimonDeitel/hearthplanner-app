import XCTest
@testable import Hearth

final class SchoolMathTests: XCTestCase {

    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
    }

    private func fact(_ date: Date,
                      kid: String = "Ada",
                      subject: String = "Reading",
                      title: String = "Lesson",
                      minutes: Int = 30,
                      done: Bool = true) -> LessonFact {
        LessonFact(date: date, kidName: kid, subjectName: subject, title: title, minutes: minutes, isDone: done)
    }

    // MARK: - Hours roll-up math

    func testCompletedMinutesCountsOnlyDoneLessons() {
        let facts = [
            fact(day(2026, 9, 1), minutes: 30, done: true),
            fact(day(2026, 9, 1), minutes: 45, done: true),
            fact(day(2026, 9, 2), minutes: 60, done: false)
        ]
        XCTAssertEqual(SchoolMath.completedMinutes(facts), 75)
        XCTAssertEqual(SchoolMath.completedHours(facts), 1.25)
    }

    func testHoursBySubjectGroupsAndSorts() {
        let facts = [
            fact(day(2026, 9, 1), subject: "Math", minutes: 90),
            fact(day(2026, 9, 2), subject: "Reading", minutes: 30),
            fact(day(2026, 9, 3), subject: "Math", minutes: 30),
            fact(day(2026, 9, 3), subject: "Science", minutes: 45, done: false)
        ]
        let rollup = SchoolMath.hoursBySubject(facts)
        XCTAssertEqual(rollup.count, 2, "Undone science lesson must not appear")
        XCTAssertEqual(rollup[0], SubjectHours(subjectName: "Math", hours: 2.0))
        XCTAssertEqual(rollup[1], SubjectHours(subjectName: "Reading", hours: 0.5))
    }

    // MARK: - Attendance counting

    func testDaysAttendedCountsDistinctDaysWithCompletions() {
        let facts = [
            fact(day(2026, 9, 1)),
            fact(day(2026, 9, 1), subject: "Math"),   // same day, still one attendance day
            fact(day(2026, 9, 2)),
            fact(day(2026, 9, 3), done: false)         // not done, does not count
        ]
        XCTAssertEqual(SchoolMath.daysAttended(facts), 2)
    }

    func testFactsInIntervalFiltersInclusiveStartExclusiveEnd() {
        let interval = DateInterval(start: day(2026, 9, 1), end: day(2026, 10, 1))
        let facts = [
            fact(day(2026, 8, 31)),
            fact(day(2026, 9, 1)),
            fact(day(2026, 9, 30)),
            fact(day(2026, 10, 1))
        ]
        let filtered = SchoolMath.facts(facts, in: interval)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.first?.date, day(2026, 9, 1))
        XCTAssertEqual(filtered.last?.date, day(2026, 9, 30))
    }

    // MARK: - Week copy logic

    func testCopyWeekShiftsEveryLessonForwardSevenDays() {
        let monday = day(2026, 9, 7)
        let previous = [
            LessonTemplate(date: monday, kidName: "Ada", subjectName: "Reading",
                           title: "Chapter 1", details: "", materials: "", minutes: 30),
            LessonTemplate(date: day(2026, 9, 9), kidName: "Ada", subjectName: "Math",
                           title: "Fractions", details: "d", materials: "m", minutes: 45)
        ]
        let plan = SchoolMath.copyWeekPlan(previousWeekLessons: previous,
                                           existingTargetWeek: [],
                                           calendar: calendar)
        XCTAssertEqual(plan.count, 2)
        XCTAssertEqual(plan[0].date, day(2026, 9, 14))
        XCTAssertEqual(plan[1].date, day(2026, 9, 16))
        XCTAssertEqual(plan[1].materials, "m", "Copied lessons keep their materials")
    }

    func testCopyWeekSkipsCollidingLessons() {
        let previous = [
            LessonTemplate(date: day(2026, 9, 7), kidName: "Ada", subjectName: "Reading",
                           title: "Chapter 1", details: "", materials: "", minutes: 30),
            LessonTemplate(date: day(2026, 9, 8), kidName: "Ben", subjectName: "Math",
                           title: "Counting", details: "", materials: "", minutes: 20)
        ]
        // Ada's copy already exists in the target week; Ben's does not.
        let existing = [
            LessonTemplate(date: day(2026, 9, 14), kidName: "Ada", subjectName: "Reading",
                           title: "Chapter 1", details: "", materials: "", minutes: 30)
        ]
        let plan = SchoolMath.copyWeekPlan(previousWeekLessons: previous,
                                           existingTargetWeek: existing,
                                           calendar: calendar)
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].kidName, "Ben")
        XCTAssertEqual(plan[0].date, day(2026, 9, 15))
    }

    // MARK: - Streaks

    func testStreakCountsBackFromTodayAndExcusesWeekends() {
        // Monday 2026-09-14 back through Friday 2026-09-11: weekend in between is excused.
        let facts = [
            fact(day(2026, 9, 14)),
            fact(day(2026, 9, 11)),
            fact(day(2026, 9, 10))
        ]
        let streak = SchoolMath.streak(facts, today: day(2026, 9, 14), calendar: calendar)
        XCTAssertEqual(streak, 3)
    }

    func testStreakBreaksOnMissedWeekday() {
        let facts = [
            fact(day(2026, 9, 14)),
            // 2026-09-11 (Friday) missed
            fact(day(2026, 9, 10))
        ]
        let streak = SchoolMath.streak(facts, today: day(2026, 9, 14), calendar: calendar)
        XCTAssertEqual(streak, 1)
    }

    func testStreakZeroWhenNothingRecent() {
        let facts = [fact(day(2026, 9, 1))]
        XCTAssertEqual(SchoolMath.streak(facts, today: day(2026, 9, 20), calendar: calendar), 0)
    }

    // MARK: - Report assembly

    func testBuildReportAssemblesAllFields() {
        let interval = DateInterval(start: day(2026, 8, 15), end: day(2027, 6, 15))
        let facts = [
            fact(day(2026, 9, 1), kid: "Ada", subject: "Reading", minutes: 60),
            fact(day(2026, 9, 1), kid: "Ada", subject: "Math", minutes: 30),
            fact(day(2026, 9, 2), kid: "Ada", subject: "Reading", minutes: 30),
            fact(day(2026, 9, 2), kid: "Ben", subject: "Math", minutes: 45),   // other kid: excluded
            fact(day(2026, 9, 3), kid: "Ada", subject: "Math", minutes: 50, done: false) // not done
        ]
        let report = SchoolMath.buildReport(kidName: "Ada",
                                            gradeLevel: "3",
                                            facts: facts,
                                            interval: interval,
                                            rangeLabel: "2026-2027",
                                            requiredDays: 180,
                                            calendar: calendar)
        XCTAssertEqual(report.kidName, "Ada")
        XCTAssertEqual(report.daysAttended, 2)
        XCTAssertEqual(report.requiredDays, 180)
        XCTAssertEqual(report.totalHours, 2.0)
        XCTAssertEqual(report.subjects,
                       [SubjectHours(subjectName: "Math", hours: 0.5),
                        SubjectHours(subjectName: "Reading", hours: 1.5)])
    }

    func testCSVOutputHasHeaderAndOneRowPerSubject() {
        let report = AttendanceReport(kidName: "Ada",
                                      gradeLevel: "3",
                                      rangeLabel: "2026-2027",
                                      daysAttended: 120,
                                      requiredDays: 180,
                                      totalHours: 350.5,
                                      subjects: [
                                          SubjectHours(subjectName: "Math", hours: 100),
                                          SubjectHours(subjectName: "Reading, Advanced", hours: 250.5)
                                      ])
        let csv = SchoolMath.csv(for: [report])
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3, "Header plus one row per subject")
        XCTAssertEqual(lines[0], "Student,Grade,Period,Days Attended,Required Days,Total Hours,Subject,Subject Hours")
        XCTAssertTrue(lines[1].contains("Ada,3,2026-2027,120,180,350.50,Math,100.00"))
        XCTAssertTrue(lines[2].contains("\"Reading, Advanced\""), "Commas in fields must be quoted")
    }

    func testWeekStartAndWeekDaysProduceSevenConsecutiveDays() {
        let start = SchoolMath.weekStart(containing: day(2026, 9, 10), calendar: calendar)
        let days = SchoolMath.weekDays(from: start, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        for index in 1..<7 {
            let expected = calendar.date(byAdding: .day, value: 1, to: days[index - 1])!
            XCTAssertEqual(days[index], expected)
        }
        XCTAssertTrue(days.contains { calendar.isDate($0, inSameDayAs: day(2026, 9, 10)) })
    }
}
