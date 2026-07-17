import SwiftUI
import SwiftData
import UIKit

/// Attendance and hours, rolled up automatically from checked-off lessons.
/// Exports a state-ready PDF or CSV via the share sheet.
struct LogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var store: StoreManager

    @Query(sort: \Kid.createdAt) private var kids: [Kid]
    @Query(sort: \Lesson.date) private var allLessons: [Lesson]

    @State private var monthAnchor: Date = Date()
    @State private var shareURL: URL?
    @State private var showPaywall = false
    @State private var exportFailed = false

    private var calendar: Calendar { .current }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: monthAnchor)
            ?? DateInterval(start: monthAnchor, duration: 0)
    }

    private var config: AppConfig {
        AppConfig.fetchOrCreate(in: context)
    }

    private var yearInterval: DateInterval {
        let cfg = config
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cfg.schoolYearEnd)) ?? cfg.schoolYearEnd
        return DateInterval(start: calendar.startOfDay(for: cfg.schoolYearStart), end: end)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NookBackground()
                if kids.isEmpty {
                    EmptyNookView(
                        title: "The log writes itself",
                        message: "Check off lessons in the Week tab and Hearth records attendance days and hours per subject for you.",
                        symbolName: "checkmark.seal")
                } else {
                    content
                }
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            export(kind: .pdf)
                        } label: {
                            Label("Export PDF report", systemImage: "doc.richtext")
                        }
                        Button {
                            export(kind: .csv)
                        } label: {
                            Label("Export CSV", systemImage: "tablecells")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("exportMenu")
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } })) {
                if let shareURL {
                    ActivityView(url: shareURL)
                        .presentationDetents([.medium, .large])
                }
            }
            .alert("Export failed", isPresented: $exportFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Hearth could not write the report file. Please try again.")
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 14) {
                monthPicker

                ForEach(kids) { kid in
                    KidLogCard(kid: kid,
                               monthFacts: facts(for: kid, in: monthInterval),
                               monthLabel: monthLabel)
                }

                yearPane
            }
            .padding(16)
            .padding(.bottom, 60)
        }
    }

    private var monthPicker: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            Text(monthLabel)
                .font(.nookTitle(17))
                .foregroundStyle(Color.ink)
            Spacer()
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .windowPane(cornerRadius: 14)
    }

    private var yearPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("School year")
                .font(.nookTitle(15))
                .foregroundStyle(Color.inkSoft)
            Text(yearRangeLabel)
                .font(.nookRounded(13))
                .foregroundStyle(Color.inkSoft)

            ForEach(kids) { kid in
                let facts = facts(for: kid, in: yearInterval)
                let days = SchoolMath.daysAttended(facts)
                let hours = SchoolMath.completedHours(facts)
                HStack {
                    Circle().fill(kid.tint(in: scheme)).frame(width: 9, height: 9)
                    Text(kid.name)
                        .font(.nookRounded(15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Text("\(days) / \(config.requiredDays) days")
                        .font(.nookRounded(13, weight: .medium))
                        .foregroundStyle(days >= config.requiredDays ? Color.forest : Color.inkSoft)
                    Text(String(format: "%.1f h", hours))
                        .font(.nookRounded(13, weight: .medium))
                        .foregroundStyle(Color.honey)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .windowPane()
    }

    // MARK: - Helpers

    private var monthLabel: String {
        monthAnchor.formatted(.dateTime.month(.wide).year())
    }

    private var yearRangeLabel: String {
        "\(config.schoolYearStart.formatted(date: .abbreviated, time: .omitted)) to \(config.schoolYearEnd.formatted(date: .abbreviated, time: .omitted))"
    }

    private func shiftMonth(_ direction: Int) {
        if let next = calendar.date(byAdding: .month, value: direction, to: monthAnchor) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                monthAnchor = next
            }
        }
    }

    private func facts(for kid: Kid, in interval: DateInterval) -> [LessonFact] {
        SchoolMath.facts(allLessons.filter { $0.kid === kid }.map(\.fact), in: interval)
    }

    // MARK: - Export

    private enum ExportKind { case pdf, csv }

    private func export(kind: ExportKind) {
        guard store.isPro else {
            showPaywall = true
            return
        }
        let reports = kids.map { kid in
            SchoolMath.buildReport(kidName: kid.name,
                                   gradeLevel: kid.gradeLevel,
                                   facts: allLessons.filter { $0.kid === kid }.map(\.fact),
                                   interval: yearInterval,
                                   rangeLabel: yearRangeLabel,
                                   requiredDays: config.requiredDays)
        }
        let fileName = "Hearth-Report-\(Date().formatted(.iso8601.year().month().day()))"
        let url: URL?
        switch kind {
        case .pdf: url = ReportExporter.writePDF(reports: reports, fileName: fileName)
        case .csv: url = ReportExporter.writeCSV(reports: reports, fileName: fileName)
        }
        if let url {
            shareURL = url
        } else {
            exportFailed = true
        }
    }
}

// MARK: - One kid's month card

private struct KidLogCard: View {
    @Environment(\.colorScheme) private var scheme

    var kid: Kid
    var monthFacts: [LessonFact]
    var monthLabel: String

    private var days: Int { SchoolMath.daysAttended(monthFacts) }
    private var hours: Double { SchoolMath.completedHours(monthFacts) }
    private var subjects: [SubjectHours] { SchoolMath.hoursBySubject(monthFacts) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(kid.tint(in: scheme)).frame(width: 12, height: 12)
                Text(kid.name)
                    .font(.nookTitle(18))
                    .foregroundStyle(Color.ink)
                Spacer()
            }

            HStack(spacing: 12) {
                statBlock(value: "\(days)", caption: "days attended", symbol: "calendar.badge.checkmark")
                statBlock(value: String(format: "%.1f", hours), caption: "hours logged", symbol: "clock.fill")
            }

            if subjects.isEmpty {
                Text("No completed lessons in \(monthLabel).")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkSoft)
            } else {
                VStack(spacing: 6) {
                    ForEach(subjects, id: \.subjectName) { line in
                        HStack {
                            Text(line.subjectName)
                                .font(.nookRounded(13, weight: .medium))
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Text(String(format: "%.2f h", line.hours))
                                .font(.nookRounded(13))
                                .foregroundStyle(Color.inkSoft)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .windowPane()
    }

    private func statBlock(value: String, caption: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.honey)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.nookTitle(20, weight: .bold))
                    .foregroundStyle(Color.ink)
                Text(caption)
                    .font(.nookRounded(11))
                    .foregroundStyle(Color.inkSoft)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(kid.wash(in: scheme).opacity(0.6))
        }
    }
}

// MARK: - Share sheet wrapper

struct ActivityView: UIViewControllerRepresentable {
    var url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
