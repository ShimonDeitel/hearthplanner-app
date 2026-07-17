import SwiftUI
import SwiftData

/// The hero view: a wooden-pegboard week. Days run down the page, kids run
/// across it, and every lesson hangs as a small glass card in its kid's hue.
struct WeekView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @Query(sort: \Kid.createdAt) private var kids: [Kid]
    @Query(sort: \Lesson.date) private var allLessons: [Lesson]

    @State private var weekStart: Date = SchoolMath.weekStart(containing: Date())
    @State private var slideEdge: Edge = .trailing
    @State private var editingLesson: Lesson?
    @State private var newLessonSeed: NewLessonSeed?
    @State private var showSettings = false
    @State private var copiedCount: Int?

    private var calendar: Calendar { .current }

    private var weekInterval: DateInterval {
        let end = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        return DateInterval(start: weekStart, end: end)
    }

    private var weekLessons: [Lesson] {
        allLessons.filter { $0.date >= weekInterval.start && $0.date < weekInterval.end }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NookBackground()
                if kids.isEmpty {
                    EmptyNookView(
                        title: "Light the hearth",
                        message: "Add your first learner in the Family tab, give them a color, and this board fills with their week.",
                        symbolName: "flame")
                } else {
                    weekBoard
                }
            }
            .navigationTitle("This Week")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
                ToolbarItem(placement: .principal) {
                    Text(weekLabel)
                        .font(.nookTitle(17))
                        .foregroundStyle(Color.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 2) {
                        Button { step(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityIdentifier("previousWeekButton")
                        Button { step(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityIdentifier("nextWeekButton")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $editingLesson) { lesson in
                LessonEditorView(mode: .edit(lesson))
            }
            .sheet(item: $newLessonSeed) { seed in
                LessonEditorView(mode: .create(date: seed.date, kid: seed.kid))
            }
        }
    }

    // MARK: - Board

    private var weekBoard: some View {
        VStack(spacing: 0) {
            kidHeaderRow
                .padding(.horizontal, 14)
                .padding(.top, 6)

            ScrollView {
                VStack(spacing: 12) {
                    WeekDaysStack(weekStart: weekStart,
                                  kids: kids,
                                  lessons: weekLessons,
                                  onToggle: toggle(_:),
                                  onEdit: { editingLesson = $0 },
                                  onAdd: { day, kid in newLessonSeed = NewLessonSeed(date: day, kid: kid) })
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 90)
            }
            .id(weekStart)
            .transition(.asymmetric(
                insertion: .move(edge: slideEdge).combined(with: .opacity),
                removal: .opacity))
        }
        .safeAreaInset(edge: .bottom) {
            copyWeekBar
        }
    }

    private var kidHeaderRow: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: 44)
            ForEach(kids) { kid in
                VStack(spacing: 3) {
                    Circle()
                        .fill(kid.tint(in: scheme))
                        .frame(width: 10, height: 10)
                    Text(kid.name)
                        .font(.nookRounded(13, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .windowPane(cornerRadius: 14)
    }

    private var copyWeekBar: some View {
        HStack {
            Button {
                copyLastWeek()
            } label: {
                Label(copiedCount.map { "Copied \($0) lessons" } ?? "Copy last week",
                      systemImage: copiedCount == nil ? "doc.on.doc" : "checkmark")
            }
            .buttonStyle(PillButtonStyle(prominent: true))
            .accessibilityIdentifier("copyLastWeekButton")

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    slideEdge = .trailing
                    weekStart = SchoolMath.weekStart(containing: Date())
                }
            } label: {
                Label("Today", systemImage: "scope")
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Labels and actions

    private var weekLabel: String {
        let formatter = DateIntervalFormatter()
        formatter.dateTemplate = "MMM d"
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return formatter.string(from: weekStart, to: end)
    }

    private func step(_ direction: Int) {
        guard let next = calendar.date(byAdding: .day, value: 7 * direction, to: weekStart) else { return }
        copiedCount = nil
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            slideEdge = direction > 0 ? .trailing : .leading
            weekStart = next
        }
    }

    private func toggle(_ lesson: Lesson) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            lesson.isDone.toggle()
            lesson.completedAt = lesson.isDone ? Date() : nil
        }
        try? context.save()
    }

    private func copyLastWeek() {
        guard let previousStart = calendar.date(byAdding: .day, value: -7, to: weekStart) else { return }
        let previousInterval = DateInterval(start: previousStart, end: weekStart)
        let previous = allLessons
            .filter { $0.date >= previousInterval.start && $0.date < previousInterval.end }
        let plan = SchoolMath.copyWeekPlan(previousWeekLessons: previous.map(\.template),
                                           existingTargetWeek: weekLessons.map(\.template),
                                           calendar: calendar)
        for template in plan {
            guard let kid = kids.first(where: { $0.name == template.kidName }) else { continue }
            let subject = kid.subjects.first(where: { $0.name == template.subjectName })
            let lesson = Lesson(date: template.date,
                                title: template.title,
                                details: template.details,
                                materials: template.materials,
                                estimatedMinutes: template.minutes,
                                kid: kid,
                                subject: subject)
            context.insert(lesson)
        }
        try? context.save()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            copiedCount = plan.count
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation { copiedCount = nil }
        }
    }
}

private struct NewLessonSeed: Identifiable {
    let id = UUID()
    var date: Date
    var kid: Kid
}

// MARK: - The seven day rows, cascading in

private struct WeekDaysStack: View {
    var weekStart: Date
    var kids: [Kid]
    var lessons: [Lesson]
    var onToggle: (Lesson) -> Void
    var onEdit: (Lesson) -> Void
    var onAdd: (Date, Kid) -> Void

    @State private var appeared = false

    var body: some View {
        let days = SchoolMath.weekDays(from: weekStart)
        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
            DayRow(day: day,
                   kids: kids,
                   lessons: lessons.filter { Calendar.current.isDate($0.date, inSameDayAs: day) },
                   onToggle: onToggle,
                   onEdit: onEdit,
                   onAdd: onAdd)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.35, dampingFraction: 0.82)
                    .delay(Double(index) * 0.045), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - One day of the pegboard

private struct DayRow: View {
    @Environment(\.colorScheme) private var scheme

    var day: Date
    var kids: [Kid]
    var lessons: [Lesson]
    var onToggle: (Lesson) -> Void
    var onEdit: (Lesson) -> Void
    var onAdd: (Date, Kid) -> Void

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Day peg
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.nookRounded(11, weight: .bold))
                    .foregroundStyle(isToday ? Color.honey : Color.inkSoft)
                    .textCase(.uppercase)
                Text(day.formatted(.dateTime.day()))
                    .font(.nookTitle(19, weight: .bold))
                    .foregroundStyle(isToday ? Color.honey : Color.ink)
            }
            .frame(width: 44)
            .padding(.top, 10)

            ForEach(kids) { kid in
                KidDayCell(kid: kid,
                           lessons: lessons.filter { $0.kid === kid },
                           onToggle: onToggle,
                           onEdit: onEdit,
                           onAdd: { onAdd(day, kid) })
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .windowPane(cornerRadius: 18)
        .overlay(alignment: .topLeading) {
            if isToday {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.honey.opacity(0.55), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - One kid's slot on one day

private struct KidDayCell: View {
    @Environment(\.colorScheme) private var scheme

    var kid: Kid
    var lessons: [Lesson]
    var onToggle: (Lesson) -> Void
    var onEdit: (Lesson) -> Void
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(lessons) { lesson in
                LessonChip(lesson: lesson, kid: kid, onToggle: { onToggle(lesson) })
                    .onTapGesture { onEdit(lesson) }
            }
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(kid.tint(in: scheme).opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(kid.tint(in: scheme).opacity(0.35),
                                          style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addLessonButton")
            .accessibilityLabel("Add lesson for \(kid.name)")
        }
    }
}

// MARK: - Lesson chip with blooming check-off

struct LessonChip: View {
    @Environment(\.colorScheme) private var scheme

    var lesson: Lesson
    var kid: Kid
    var onToggle: () -> Void

    @State private var bloom = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: lesson.subject?.symbolName ?? "book.closed.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(kid.tint(in: scheme))

            VStack(alignment: .leading, spacing: 1) {
                Text(lesson.title)
                    .font(.nookRounded(12, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .strikethrough(lesson.isDone, color: Color.inkSoft)
                    .lineLimit(2)
                Text("\(lesson.estimatedMinutes) min")
                    .font(.nookRounded(10))
                    .foregroundStyle(Color.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            checkButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(kid.wash(in: scheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(kid.tint(in: scheme).opacity(lesson.isDone ? 0.15 : 0.35), lineWidth: 1)
        }
        .opacity(lesson.isDone ? 0.72 : 1)
        .scaleEffect(bloom ? 1.05 : 1)
        .accessibilityIdentifier("lessonChip-\(lesson.title)")
    }

    private var checkButton: some View {
        Button {
            if !lesson.isDone {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { bloom = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bloom = false }
                }
            }
            onToggle()
        } label: {
            ZStack {
                if lesson.isDone {
                    Circle()
                        .fill(kid.tint(in: scheme).opacity(0.25))
                        .frame(width: 26, height: 26)
                }
                Image(systemName: lesson.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(lesson.isDone ? kid.tint(in: scheme) : Color.inkSoft.opacity(0.6))
                    .symbolEffect(.bounce, value: lesson.isDone)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("lessonCheck-\(lesson.title)")
    }
}
