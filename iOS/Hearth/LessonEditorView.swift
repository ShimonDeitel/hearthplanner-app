import SwiftUI
import SwiftData

/// Add or edit a single lesson block. Deliberately simple: kid, subject, what,
/// materials, and how long.
struct LessonEditorView: View {
    enum Mode {
        case create(date: Date, kid: Kid?)
        case edit(Lesson)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @Query(sort: \Kid.createdAt) private var kids: [Kid]

    let mode: Mode

    @State private var date: Date = Date()
    @State private var selectedKid: Kid?
    @State private var selectedSubject: SubjectItem?
    @State private var title: String = ""
    @State private var details: String = ""
    @State private var materials: String = ""
    @State private var minutes: Int = 30
    @State private var loaded = false

    private let minutePresets = [15, 20, 30, 45, 60, 90]

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        selectedKid != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Learner", selection: $selectedKid) {
                        ForEach(kids) { kid in
                            Text(kid.name).tag(Optional(kid))
                        }
                    }
                    Picker("Subject", selection: $selectedSubject) {
                        Text("None").tag(Optional<SubjectItem>.none)
                        ForEach(selectedKid?.subjects.sorted { $0.name < $1.name } ?? []) { subject in
                            Label(subject.name, systemImage: subject.symbolName)
                                .tag(Optional(subject))
                        }
                    }
                    DatePicker("Day", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Lesson")
                        .accessibilityIdentifier("editorHeader")
                }

                Section("What") {
                    TextField("Title, e.g. Chapter 4 read-aloud", text: $title)
                        .accessibilityIdentifier("lessonTitleField")
                    TextField("Notes (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("lessonDetailsField")
                    TextField("Materials (optional)", text: $materials, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("lessonMaterialsField")
                }

                Section("Time") {
                    HStack(spacing: 6) {
                        ForEach(minutePresets, id: \.self) { preset in
                            Button {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                    minutes = preset
                                }
                            } label: {
                                Text("\(preset)")
                                    .font(.nookRounded(13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background {
                                        Capsule().fill(minutes == preset
                                            ? Color.honey.opacity(0.85)
                                            : Color.inkSoft.opacity(0.12))
                                    }
                                    .foregroundStyle(minutes == preset ? Color.white : Color.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Stepper("\(minutes) minutes", value: $minutes, in: 5...480, step: 5)
                        .font(.nookRounded(15))
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if case .edit(let lesson) = mode {
                                context.delete(lesson)
                                try? context.save()
                            }
                            dismiss()
                        } label: {
                            Label("Delete lesson", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookBackground())
            .dismissesKeyboardOnTap()
            .navigationTitle(isEditing ? "Edit Lesson" : "New Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveLessonButton")
                }
            }
            .onAppear(perform: load)
            .onChange(of: selectedKid) { _, newKid in
                if let subject = selectedSubject, subject.kid !== newKid {
                    selectedSubject = newKid?.subjects.sorted { $0.name < $1.name }.first
                }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .create(let seedDate, let seedKid):
            date = seedDate
            selectedKid = seedKid ?? kids.first
            selectedSubject = (seedKid ?? kids.first)?.subjects.sorted { $0.name < $1.name }.first
        case .edit(let lesson):
            date = lesson.date
            selectedKid = lesson.kid
            selectedSubject = lesson.subject
            title = lesson.title
            details = lesson.details
            materials = lesson.materials
            minutes = lesson.estimatedMinutes
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create:
            let lesson = Lesson(date: date,
                                title: trimmed,
                                details: details,
                                materials: materials,
                                estimatedMinutes: minutes,
                                kid: selectedKid,
                                subject: selectedSubject)
            context.insert(lesson)
        case .edit(let lesson):
            lesson.date = Calendar.current.startOfDay(for: date)
            lesson.title = trimmed
            lesson.details = details
            lesson.materials = materials
            lesson.estimatedMinutes = minutes
            lesson.kid = selectedKid
            lesson.subject = selectedSubject
        }
        try? context.save()
        dismiss()
    }
}
