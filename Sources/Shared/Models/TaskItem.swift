import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var text: String
    var sectionID: UUID
    var createdAt: Date
    var isDone: Bool
    var doneAt: Date?
    var isPinned: Bool
    var pinOrder: Int?
    var orderIndex: Double

    init(
        id: UUID = UUID(),
        text: String,
        sectionID: UUID,
        createdAt: Date = .now,
        isDone: Bool = false,
        doneAt: Date? = nil,
        isPinned: Bool = false,
        pinOrder: Int? = nil,
        orderIndex: Double = 0
    ) {
        self.id = id
        self.text = text
        self.sectionID = sectionID
        self.createdAt = createdAt
        self.isDone = isDone
        self.doneAt = doneAt
        self.isPinned = isPinned
        self.pinOrder = pinOrder
        self.orderIndex = orderIndex
    }
}
