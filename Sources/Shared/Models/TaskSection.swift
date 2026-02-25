import Foundation
import SwiftData

@Model
final class TaskSection {
    @Attribute(.unique) var id: UUID
    var name: String
    var orderIndex: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        orderIndex: Double,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.createdAt = createdAt
    }
}
