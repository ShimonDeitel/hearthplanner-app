import SwiftUI
import SwiftData

/// Per-subject progress against weekly targets, plus a learning streak per kid.
struct ProgressTabView: View {
    @Environment(\.colorScheme) private var scheme

    @Query(sort: \Kid.createdAt) private var kids: [Kid]
    @Query(sort: \Lesson.date) private var allLessons: [Lesson]

    @State private var barsGrown = false

    private var calendar: Calendar { .current }

    private var weekInterval: DateInterval {
        let start = SchoolMath.weekStart(containing: Date())
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NookBackground()
                if kids.isEmpty {
                    EmptyNookView(
                        title: "Nothing to chart yet",
                        message: "Once you add learners and check off lessons, weekly progress and streaks grow here.",
                        symbolName: "chart.bar")
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(kids) { kid in
                                KidProgressCard(kid: kid,
                                                facts: facts(for: kid),
                                                weekFacts: weekFacts(for: kid),
                                                grown: barsGrown)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("Progress")
            .onAppear {
                barsGrown = false
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.15)) {
                    barsGrown = true
                }
            }
        }
    }

    private func facts(for kid: Kid) -> [LessonFact] {
        allLessons.filter { $0.kid === kid }.map(\.fact)
    }

    private func weekFacts(for kid: Kid) -> [LessonFact] {
        SchoolMath.facts(facts(for: kid), in: weekInterval)
    }
}

// MARK: - One kid's progress card

private struct KidProgressCard: View {
    @Environment(\.colorScheme) private var scheme

    var kid: Kid
    var facts: [LessonFact]
    var weekFacts: [LessonFact]
    var grown: Bool

    private var streak: Int {
        SchoolMath.streak(facts, today: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .fill(kid.tint(in: scheme))
                    .frame(width: 12, height: 12)
                Text(kid.name)
                    .font(.nookTitle(19))
                    .foregroundStyle(Color.ink)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(streak > 0 ? Color.lampGlow : Color.inkSoft.opacity(0.4))
                    Text("\(streak) day\(streak == 1 ? "" : "s")")
                        .font(.nookRounded(13, weight: .bold))
                        .foregroundStyle(streak > 0 ? Color.ink : Color.inkSoft)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background { Capsule().fill(Color.lampGlow.opacity(streak > 0 ? 0.18 : 0.06)) }
            }

            if kid.subjects.isEmpty {
                Text("No subjects yet. Add some in the Family tab.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSoft)
            }

            ForEach(kid.subjects.sorted { $0.name < $1.name }) { subject in
                SubjectBar(subject: subject,
                           kidTint: kid.tint(in: scheme),
                           doneHours: doneHours(for: subject),
                           grown: grown)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .windowPane()
    }

    private func doneHours(for subject: SubjectItem) -> Double {
        SchoolMath.completedHours(weekFacts.filter { $0.subjectName == subject.name })
    }
}

// MARK: - Animated subject bar

private struct SubjectBar: View {
    var subject: SubjectItem
    var kidTint: Color
    var doneHours: Double
    var grown: Bool

    private var fraction: Double {
        guard subject.weeklyTargetHours > 0 else { return 0 }
        return min(1, doneHours / subject.weeklyTargetHours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(subject.name, systemImage: subject.symbolName)
                    .font(.nookRounded(14, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text(String(format: "%.1f / %.1f h", doneHours, subject.weeklyTargetHours))
                    .font(.nookRounded(12, weight: .medium))
                    .foregroundStyle(fraction >= 1 ? kidTint : Color.inkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.inkSoft.opacity(0.14))
                    Capsule()
                        .fill(
                            LinearGradient(colors: [kidTint.opacity(0.75), kidTint],
                                           startPoint: .leading, endPoint: .trailing))
                        .frame(width: grown ? geo.size.width * fraction : 0)
                    if fraction >= 1 {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(Color.white)
                                .padding(.trailing, 5)
                        }
                    }
                }
            }
            .frame(height: 10)
        }
    }
}
