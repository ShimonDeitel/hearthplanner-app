import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var kids: [Kid]

    var body: some View {
        TabView {
            WeekView()
                .tabItem { Label("Week", systemImage: "calendar") }

            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }

            LogView()
                .tabItem { Label("Log", systemImage: "checkmark.seal.fill") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }

            FamilyView()
                .tabItem { Label("Family", systemImage: "person.2.fill") }
        }
    }
}

/// Friendly first-run card shown wherever content needs at least one kid.
struct EmptyNookView: View {
    var title: String
    var message: String
    var symbolName: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.honey)
                .padding(.bottom, 2)
            Text(title)
                .font(.nookTitle(22))
                .foregroundStyle(Color.ink)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: 420)
        .windowPane()
        .padding(24)
    }
}
