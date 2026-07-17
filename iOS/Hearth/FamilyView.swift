import SwiftUI
import SwiftData

/// Kids and their subjects. Each kid owns a hue used across the whole app.
struct FamilyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var store: StoreManager

    @Query(sort: \Kid.createdAt) private var kids: [Kid]

    @State private var editingKid: Kid?
    @State private var showNewKid = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                NookBackground()
                if kids.isEmpty {
                    EmptyNookView(
                        title: "Who is learning?",
                        message: "Add each of your kids with a grade and a color. Their color follows them through the planner.",
                        symbolName: "person.crop.circle.badge.plus")
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(kids) { kid in
                                NavigationLink(value: kid) {
                                    KidCard(kid: kid)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("Family")
            .navigationDestination(for: Kid.self) { kid in
                KidDetailView(kid: kid)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if store.canAddKid(currentCount: kids.count) {
                            showNewKid = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addKidButton")
                }
            }
            .sheet(isPresented: $showNewKid) { KidEditorView(kid: nil) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

// MARK: - Kid card

private struct KidCard: View {
    @Environment(\.colorScheme) private var scheme
    var kid: Kid

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(kid.wash(in: scheme))
                    .frame(width: 52, height: 52)
                Circle()
                    .strokeBorder(kid.tint(in: scheme), lineWidth: 2)
                    .frame(width: 52, height: 52)
                Text(kid.name.prefix(1).uppercased())
                    .font(.nookTitle(22, weight: .bold))
                    .foregroundStyle(kid.tint(in: scheme))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(kid.name)
                    .font(.nookTitle(19))
                    .foregroundStyle(Color.ink)
                Text(kid.gradeLevel.isEmpty ? "No grade set" : "Grade \(kid.gradeLevel)")
                    .font(.nookRounded(13))
                    .foregroundStyle(Color.inkSoft)
                Text("\(kid.subjects.count) subjects")
                    .font(.nookRounded(12))
                    .foregroundStyle(kid.tint(in: scheme))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkSoft.opacity(0.6))
        }
        .padding(14)
        .windowPane(cornerRadius: 18)
    }
}

// MARK: - Kid detail: identity + subjects

struct KidDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @Bindable var kid: Kid

    @State private var editingSubject: SubjectItem?
    @State private var showNewSubject = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            NookBackground()
            ScrollView {
                VStack(spacing: 14) {
                    identityPane
                    subjectsPane
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Remove \(kid.name)", systemImage: "trash")
                            .font(.nookRounded(14, weight: .semibold))
                    }
                    .padding(.top, 8)
                }
                .padding(16)
                .padding(.bottom, 60)
            }
        }
        .navigationTitle(kid.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewSubject) { SubjectEditorView(kid: kid, subject: nil) }
        .sheet(item: $editingSubject) { subject in
            SubjectEditorView(kid: kid, subject: subject)
        }
        .confirmationDialog("Remove \(kid.name) and all their lessons?",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                context.delete(kid)
                try? context.save()
                dismiss()
            }
        }
    }

    private var identityPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Identity")
                .font(.nookTitle(15))
                .foregroundStyle(Color.inkSoft)

            TextField("Name", text: $kid.name)
                .font(.nookTitle(20))
                .accessibilityIdentifier("kidNameField")

            TextField("Grade level, e.g. 4", text: $kid.gradeLevel)
                .font(.nookRounded(15))
                .accessibilityIdentifier("kidGradeField")

            Text("Color")
                .font(.nookRounded(13, weight: .semibold))
                .foregroundStyle(Color.inkSoft)
            HStack(spacing: 10) {
                ForEach(KidPalette.presets, id: \.hue) { preset in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            kid.hue = preset.hue
                        }
                        try? context.save()
                    } label: {
                        Circle()
                            .fill(KidPalette.color(hue: preset.hue, in: scheme))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if abs(kid.hue - preset.hue) < 0.5 {
                                    Circle().strokeBorder(Color.ink, lineWidth: 2).padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(preset.name)")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .windowPane()
        .dismissesKeyboardOnTap()
    }

    private var subjectsPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Subjects")
                    .font(.nookTitle(15))
                    .foregroundStyle(Color.inkSoft)
                Spacer()
                Button {
                    showNewSubject = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.nookRounded(13, weight: .semibold))
                }
                .accessibilityIdentifier("addSubjectButton")
            }

            if kid.subjects.isEmpty {
                Text("Add subjects like Reading, Math, or Nature Study, each with a weekly hours target.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSoft)
                    .padding(.vertical, 6)
            }

            ForEach(kid.subjects.sorted { $0.name < $1.name }) { subject in
                Button {
                    editingSubject = subject
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: subject.symbolName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(kid.tint(in: scheme))
                            .frame(width: 28)
                        Text(subject.name)
                            .font(.nookRounded(15, weight: .semibold))
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Text(String(format: "%.1f h/week", subject.weeklyTargetHours))
                            .font(.nookRounded(13))
                            .foregroundStyle(Color.inkSoft)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(kid.wash(in: scheme).opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .windowPane()
    }
}

// MARK: - New kid sheet

struct KidEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var kid: Kid?

    @State private var name = ""
    @State private var grade = ""
    @State private var hue: Double = KidPalette.presets[1].hue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("newKidNameField")
                    TextField("Grade level, e.g. 4", text: $grade)
                } header: {
                    Text("Learner")
                        .accessibilityIdentifier("kidEditorHeader")
                }
                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(KidPalette.presets, id: \.hue) { preset in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    hue = preset.hue
                                }
                            } label: {
                                Circle()
                                    .fill(KidPalette.color(hue: preset.hue, in: scheme))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if abs(hue - preset.hue) < 0.5 {
                                            Circle().strokeBorder(Color.ink, lineWidth: 2).padding(-4)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(preset.name)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookBackground())
            .dismissesKeyboardOnTap()
            .navigationTitle("New Learner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newKid = Kid(name: name.trimmingCharacters(in: .whitespaces),
                                         gradeLevel: grade.trimmingCharacters(in: .whitespaces),
                                         hue: hue)
                        context.insert(newKid)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("saveKidButton")
                }
            }
        }
    }
}

// MARK: - Subject editor sheet

struct SubjectEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var kid: Kid
    var subject: SubjectItem?

    @State private var name = ""
    @State private var symbolName = "book.closed.fill"
    @State private var targetHours: Double = 3
    @State private var loaded = false

    private static let symbols = [
        "book.closed.fill", "book.fill", "sum", "function", "globe.americas.fill",
        "leaf.fill", "flask.fill", "paintpalette.fill", "music.note", "figure.run",
        "pencil.and.outline", "text.book.closed.fill", "clock.fill", "hammer.fill",
        "theatermasks.fill", "map.fill", "atom", "keyboard.fill", "camera.fill", "cross.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Subject name, e.g. Reading", text: $name)
                        .accessibilityIdentifier("subjectNameField")
                } header: {
                    Text("Subject")
                        .accessibilityIdentifier("subjectEditorHeader")
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Self.symbols, id: \.self) { symbol in
                            Button {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                    symbolName = symbol
                                }
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 44, height: 40)
                                    .background {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(symbolName == symbol
                                                ? kid.tint(in: scheme).opacity(0.25)
                                                : Color.inkSoft.opacity(0.08))
                                    }
                                    .foregroundStyle(symbolName == symbol ? kid.tint(in: scheme) : Color.inkSoft)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Weekly target") {
                    Stepper(String(format: "%.1f hours per week", targetHours),
                            value: $targetHours, in: 0.5...40, step: 0.5)
                        .font(.nookRounded(15))
                }

                if subject != nil {
                    Section {
                        Button(role: .destructive) {
                            if let subject {
                                context.delete(subject)
                                try? context.save()
                            }
                            dismiss()
                        } label: {
                            Label("Delete subject", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookBackground())
            .dismissesKeyboardOnTap()
            .navigationTitle(subject == nil ? "New Subject" : "Edit Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("saveSubjectButton")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let subject {
                    name = subject.name
                    symbolName = subject.symbolName
                    targetHours = subject.weeklyTargetHours
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let subject {
            subject.name = trimmed
            subject.symbolName = symbolName
            subject.weeklyTargetHours = targetHours
        } else {
            let newSubject = SubjectItem(name: trimmed,
                                         symbolName: symbolName,
                                         weeklyTargetHours: targetHours,
                                         kid: kid)
            context.insert(newSubject)
        }
        try? context.save()
        dismiss()
    }
}
