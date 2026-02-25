import AppIntents
import Foundation
import SwiftData

struct TaskSectionEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "区分")
    static var defaultQuery = TaskSectionQuery()

    let id: UUID
    let name: String

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(section: TaskSection) {
        self.init(id: section.id, name: section.name)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TaskSectionQuery: EntityQuery {
    func entities(for identifiers: [TaskSectionEntity.ID]) async throws -> [TaskSectionEntity] {
        let sections = try fetchSections()
        let idSet = Set(identifiers)
        return sections
            .filter { idSet.contains($0.id) }
            .map(TaskSectionEntity.init)
    }

    func suggestedEntities() async throws -> [TaskSectionEntity] {
        try fetchSections().map(TaskSectionEntity.init)
    }

    func defaultResult() async -> TaskSectionEntity? {
        (try? fetchSections().first).map(TaskSectionEntity.init)
    }

    private func fetchSections() throws -> [TaskSection] {
        let container = try SharedStore.makeContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskSection>()
        return try context.fetch(descriptor).sorted {
            if $0.orderIndex != $1.orderIndex {
                return $0.orderIndex < $1.orderIndex
            }
            return $0.createdAt < $1.createdAt
        }
    }
}
