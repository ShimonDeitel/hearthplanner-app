import SwiftUI
import SwiftData

/// Books and materials per subject, with a three-state reading status.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @Query(sort: \Kid.createdAt) private var kids: [Kid]
    @Query(sort: \ResourceItem.createdAt) private var resources: [ResourceItem]

    @State private var showNewResource = false
    @State private var editingResource: ResourceItem?

    private var hasSubjects: Bool {
        kids.contains { !$0.subjects.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NookBackground()
                if !hasSubjects {
                    EmptyNookView(
                        title: "An empty shelf",
                        message: "Add kids and subjects first, then stock this shelf with the books and materials you plan to use.",
                        symbolName: "books.vertical")
                } else {
                    shelf
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewResource = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!hasSubjects)
                    .accessibilityIdentifier("addResourceButton")
                }
            }
            .sheet(isPresented: $showNewResource) { ResourceEditorView(resource: nil) }
            .sheet(item: $editingResource) { resource in
                ResourceEditorView(resource: resource)
            }
        }
    }

    private var shelf: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(kids) { kid in
                    ForEach(kid.subjects.sorted { $0.name < $1.name }) { subject in
                        let items = resources.filter { $0.subject === subject }
                        if !items.isEmpty {
                            SubjectShelf(kid: kid, subject: subject, items: items,
                                         onCycle: cycle(_:),
                                         onEdit: { editingResource = $0 })
                        }
                    }
                }
                if resources.isEmpty {
                    EmptyNookView(
                        title: "Stock the shelf",
                        message: "Tap the plus button to add a book or resource to any subject.",
                        symbolName: "plus.circle")
                }
            }
            .padding(16)
            .padding(.bottom, 60)
        }
    }

    private func cycle(_ resource: ResourceItem) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            resource.status = resource.status.next
        }
        try? context.save()
    }
}

// MARK: - One subject's shelf

private struct SubjectShelf: View {
    @Environment(\.colorScheme) private var scheme

    var kid: Kid
    var subject: SubjectItem
    var items: [ResourceItem]
    var onCycle: (ResourceItem) -> Void
    var onEdit: (ResourceItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: subject.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(kid.tint(in: scheme))
                Text(subject.name)
                    .font(.nookTitle(16))
                    .foregroundStyle(Color.ink)
                Text(kid.name)
                    .font(.nookRounded(12, weight: .semibold))
                    .foregroundStyle(kid.tint(in: scheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background { Capsule().fill(kid.wash(in: scheme)) }
                Spacer()
            }

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Button {
                        onCycle(item)
                    } label: {
                        Image(systemName: item.status.symbolName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(item.status == .done ? kid.tint(in: scheme) : Color.inkSoft)
                            .symbolEffect(.bounce, value: item.statusRaw)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.nookRounded(14, weight: .semibold))
                            .foregroundStyle(Color.ink)
                            .strikethrough(item.status == .done, color: Color.inkSoft)
                        if !item.note.isEmpty {
                            Text(item.note)
                                .font(.nookRounded(12))
                                .foregroundStyle(Color.inkSoft)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(item.status.rawValue)
                        .font(.nookRounded(11, weight: .medium))
                        .foregroundStyle(Color.inkSoft)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(kid.wash(in: scheme).opacity(0.55))
                }
                .contentShape(Rectangle())
                .onTapGesture { onEdit(item) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .windowPane()
    }
}

// MARK: - Resource editor

struct ResourceEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Kid.createdAt) private var kids: [Kid]

    var resource: ResourceItem?

    @State private var title = ""
    @State private var note = ""
    @State private var selectedSubject: SubjectItem?
    @State private var status: ResourceStatus = .notStarted
    @State private var loaded = false

    private var allSubjects: [(kid: Kid, subject: SubjectItem)] {
        kids.flatMap { kid in
            kid.subjects.sorted { $0.name < $1.name }.map { (kid, $0) }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title, e.g. Story of the World Vol. 1", text: $title)
                        .accessibilityIdentifier("resourceTitleField")
                    TextField("Note (optional)", text: $note)
                        .accessibilityIdentifier("resourceNoteField")
                } header: {
                    Text("Resource")
                        .accessibilityIdentifier("resourceEditorHeader")
                }

                Section("Belongs to") {
                    Picker("Subject", selection: $selectedSubject) {
                        ForEach(allSubjects, id: \.subject) { pair in
                            Text("\(pair.subject.name) (\(pair.kid.name))")
                                .tag(Optional(pair.subject))
                        }
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ResourceStatus.allCases, id: \.self) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if resource != nil {
                    Section {
                        Button(role: .destructive) {
                            if let resource {
                                context.delete(resource)
                                try? context.save()
                            }
                            dismiss()
                        } label: {
                            Label("Delete resource", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookBackground())
            .dismissesKeyboardOnTap()
            .navigationTitle(resource == nil ? "New Resource" : "Edit Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || selectedSubject == nil)
                        .accessibilityIdentifier("saveResourceButton")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let resource {
                    title = resource.title
                    note = resource.note
                    selectedSubject = resource.subject
                    status = resource.status
                } else {
                    selectedSubject = allSubjects.first?.subject
                }
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if let resource {
            resource.title = trimmed
            resource.note = note
            resource.subject = selectedSubject
            resource.status = status
        } else {
            let newResource = ResourceItem(title: trimmed, note: note, status: status, subject: selectedSubject)
            context.insert(newResource)
        }
        try? context.save()
        dismiss()
    }
}
