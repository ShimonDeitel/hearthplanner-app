import SwiftUI
import SwiftData

@main
struct HearthApp: App {
    @StateObject private var store = StoreManager()

    let container: ModelContainer

    init() {
        let schema = Schema([Kid.self, SubjectItem.self, Lesson.self, ResourceItem.self, AppConfig.self])
        let isUITest = ProcessInfo.processInfo.arguments.contains("--uitest")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITest)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create model container: \(error)")
        }
        if isUITest {
            Self.seedForUITests(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(.forest)
        }
        .modelContainer(container)
    }

    @MainActor
    private static func seedForUITests(container: ModelContainer) {
        let context = container.mainContext
        let kid = Kid(name: "Ada", gradeLevel: "3", hue: 38)
        context.insert(kid)
        let reading = SubjectItem(name: "Reading", symbolName: "book.fill", weeklyTargetHours: 4, kid: kid)
        let math = SubjectItem(name: "Math", symbolName: "sum", weeklyTargetHours: 3, kid: kid)
        context.insert(reading)
        context.insert(math)
        try? context.save()
    }
}
