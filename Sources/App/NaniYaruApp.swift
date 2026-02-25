import SwiftUI
import SwiftData

@main
struct NaniYaruApp: App {
    private let container: ModelContainer
    @State private var routeSectionID: UUID?

    init() {
        do {
            container = try SharedStore.makeContainer(performResetIfNeeded: true)
            let context = ModelContext(container)
            try TaskRepository.bootstrapIfNeeded(context: context)
        } catch {
            fatalError("Failed to initialize shared store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(routeSectionID: $routeSectionID)
                .onOpenURL { url in
                    guard let route = AppRoute.from(url: url) else {
                        return
                    }

                    switch route {
                    case .dashboard:
                        routeSectionID = nil
                    case let .section(sectionID):
                        routeSectionID = sectionID
                    }
                }
        }
        .modelContainer(container)
    }
}
