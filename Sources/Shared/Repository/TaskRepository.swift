import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

enum TaskRepositoryError: LocalizedError {
    case invalidTaskText
    case invalidSectionName
    case duplicateSectionName
    case invalidSectionOrder
    case pinLimitReached(limit: Int)

    var errorDescription: String? {
        switch self {
        case .invalidTaskText:
            return "タスクは1〜120文字で入力してください"
        case .invalidSectionName:
            return "区分名は1〜12文字で入力してください"
        case .duplicateSectionName:
            return "同じ名前の区分がすでにあります"
        case .invalidSectionOrder:
            return "区分の並び順を更新できませんでした"
        case let .pinLimitReached(limit):
            return "ピン留めは1区分あたり最大\(limit)件です"
        }
    }
}

enum TaskRepository {
    static let maxPinnedPerSection = 3
    static let maxSectionNameLength = 12
    static let maxTaskTextLength = 120
    static let defaultSectionNames = ["今日", "今週", "今月", "今年", "いつか"]

    static func bootstrapIfNeeded(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<TaskSection>())
        guard existing.isEmpty else {
            return
        }

        for (index, name) in defaultSectionNames.enumerated() {
            let section = TaskSection(name: name, orderIndex: Double(index))
            context.insert(section)
        }

        try context.save()
        reloadWidgetTimelines()
    }

    static func normalizedText(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.count <= maxTaskTextLength {
            return trimmed
        }

        return String(trimmed.prefix(maxTaskTextLength))
    }

    static func normalizedSectionName(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.count <= maxSectionNameLength {
            return trimmed
        }

        return String(trimmed.prefix(maxSectionNameLength))
    }

    static func orderedSections(from sections: [TaskSection]) -> [TaskSection] {
        sections.sorted { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    static func orderedTasks(from tasks: [TaskItem], in sectionID: UUID, includeDone: Bool = false) -> [TaskItem] {
        tasks
            .filter { task in
                task.sectionID == sectionID && (includeDone || !task.isDone)
            }
            .sorted(by: taskSort)
    }

    static func addSection(name: String, context: ModelContext) throws -> TaskSection {
        guard let normalized = normalizedSectionName(from: name) else {
            throw TaskRepositoryError.invalidSectionName
        }

        let sections = try context.fetch(FetchDescriptor<TaskSection>())
        if hasDuplicateName(normalized, in: sections) {
            throw TaskRepositoryError.duplicateSectionName
        }

        let nextOrder = (sections.map(\.orderIndex).max() ?? -1) + 1
        let section = TaskSection(name: normalized, orderIndex: nextOrder)
        context.insert(section)
        try context.save()
        reloadWidgetTimelines()
        return section
    }

    static func renameSection(_ section: TaskSection, to newName: String, context: ModelContext) throws {
        guard let normalized = normalizedSectionName(from: newName) else {
            throw TaskRepositoryError.invalidSectionName
        }

        let sections = try context.fetch(FetchDescriptor<TaskSection>())
        if sections.contains(where: { $0.id != section.id && $0.name.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            throw TaskRepositoryError.duplicateSectionName
        }

        section.name = normalized
        try context.save()
        reloadWidgetTimelines()
    }

    static func deleteSection(_ section: TaskSection, context: ModelContext) throws {
        let sectionID = section.id
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate<TaskItem> { task in
            task.sectionID == sectionID
        })
        let tasks = try context.fetch(descriptor)
        for task in tasks {
            context.delete(task)
        }

        context.delete(section)
        try context.save()
        reloadWidgetTimelines()
    }

    static func reorderSections(
        _ sections: [TaskSection],
        from source: IndexSet,
        to destination: Int,
        context: ModelContext
    ) throws {
        var reordered = orderedSections(from: sections)
        moveItems(&reordered, from: source, to: destination)

        for (index, section) in reordered.enumerated() {
            section.orderIndex = Double(index)
        }

        try context.save()
        reloadWidgetTimelines()
    }

    static func setSectionOrder(
        _ orderedSectionIDs: [UUID],
        in sections: [TaskSection],
        context: ModelContext
    ) throws {
        guard orderedSectionIDs.count == sections.count else {
            throw TaskRepositoryError.invalidSectionOrder
        }

        let knownIDs = Set(sections.map(\.id))
        let candidateIDs = Set(orderedSectionIDs)
        guard knownIDs == candidateIDs else {
            throw TaskRepositoryError.invalidSectionOrder
        }

        let sectionByID = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0) })
        for (index, sectionID) in orderedSectionIDs.enumerated() {
            guard let section = sectionByID[sectionID] else {
                throw TaskRepositoryError.invalidSectionOrder
            }
            section.orderIndex = Double(index)
        }

        try context.save()
        reloadWidgetTimelines()
    }

    static func addTask(text: String, to section: TaskSection, allTasks: [TaskItem], context: ModelContext) throws {
        guard let normalized = normalizedText(from: text) else {
            throw TaskRepositoryError.invalidTaskText
        }

        let nextOrder = nextTaskOrderIndex(in: section.id, tasks: allTasks)
        let task = TaskItem(text: normalized, sectionID: section.id, orderIndex: nextOrder)
        context.insert(task)
        try context.save()
        reloadWidgetTimelines()
    }

    static func toggleCompletion(for task: TaskItem, allTasks: [TaskItem], context: ModelContext) throws {
        let sectionID = task.sectionID
        task.isDone.toggle()
        task.doneAt = task.isDone ? Date() : nil

        if task.isDone {
            task.isPinned = false
            task.pinOrder = nil
            compactPinOrders(in: sectionID, tasks: allTasks)
        }

        try context.save()
        reloadWidgetTimelines()
    }

    static func delete(_ task: TaskItem, allTasks: [TaskItem], context: ModelContext) throws {
        let sectionID = task.sectionID
        let wasPinned = task.isPinned
        context.delete(task)

        if wasPinned {
            compactPinOrders(in: sectionID, tasks: allTasks.filter { $0.id != task.id })
        }

        try context.save()
        reloadWidgetTimelines()
    }

    static func togglePin(for task: TaskItem, allTasks: [TaskItem], context: ModelContext) throws {
        let sectionID = task.sectionID

        if task.isPinned {
            task.isPinned = false
            task.pinOrder = nil
            compactPinOrders(in: sectionID, tasks: allTasks)
        } else {
            let pinned = allTasks.filter {
                $0.sectionID == sectionID && $0.isPinned && !$0.isDone && $0.id != task.id
            }

            guard pinned.count < maxPinnedPerSection else {
                throw TaskRepositoryError.pinLimitReached(limit: maxPinnedPerSection)
            }

            task.isPinned = true
            task.pinOrder = nextAvailablePinOrder(in: sectionID, tasks: allTasks)
        }

        try context.save()
        reloadWidgetTimelines()
    }

    static func moveTask(
        _ task: TaskItem,
        to section: TaskSection,
        allTasks: [TaskItem],
        context: ModelContext
    ) throws {
        let sourceSectionID = task.sectionID
        guard sourceSectionID != section.id else {
            return
        }

        if task.isPinned {
            let pinnedInDestination = allTasks.filter {
                $0.sectionID == section.id && $0.isPinned && !$0.isDone && $0.id != task.id
            }
            guard pinnedInDestination.count < maxPinnedPerSection else {
                throw TaskRepositoryError.pinLimitReached(limit: maxPinnedPerSection)
            }
        }

        task.sectionID = section.id
        task.orderIndex = nextTaskOrderIndex(in: section.id, tasks: allTasks)

        if task.isPinned {
            task.pinOrder = nextAvailablePinOrder(in: section.id, tasks: allTasks)
            compactPinOrders(in: sourceSectionID, tasks: allTasks)
        }

        try context.save()
        reloadWidgetTimelines()
    }

    static func reorderTasks(
        in section: TaskSection,
        tasks: [TaskItem],
        from source: IndexSet,
        to destination: Int,
        context: ModelContext
    ) throws {
        var ordered = orderedTasks(from: tasks, in: section.id, includeDone: false)
        moveItems(&ordered, from: source, to: destination)

        for (index, task) in ordered.enumerated() {
            task.orderIndex = Double(index)
        }

        try context.save()
        reloadWidgetTimelines()
    }

    private static func taskSort(lhs: TaskItem, rhs: TaskItem) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }

        if lhs.isPinned && rhs.isPinned {
            let leftOrder = lhs.pinOrder ?? Int.max
            let rightOrder = rhs.pinOrder ?? Int.max
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }
        }

        if lhs.orderIndex != rhs.orderIndex {
            return lhs.orderIndex < rhs.orderIndex
        }

        return lhs.createdAt > rhs.createdAt
    }

    private static func hasDuplicateName(_ name: String, in sections: [TaskSection]) -> Bool {
        sections.contains { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    private static func nextTaskOrderIndex(in sectionID: UUID, tasks: [TaskItem]) -> Double {
        let currentMax = tasks
            .filter { $0.sectionID == sectionID }
            .map(\.orderIndex)
            .max() ?? -1
        return currentMax + 1
    }

    private static func compactPinOrders(in sectionID: UUID, tasks: [TaskItem]) {
        let pinned = tasks
            .filter { $0.sectionID == sectionID && $0.isPinned && !$0.isDone }
            .sorted { lhs, rhs in
                let leftOrder = lhs.pinOrder ?? Int.max
                let rightOrder = rhs.pinOrder ?? Int.max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return lhs.createdAt > rhs.createdAt
            }

        for (index, task) in pinned.enumerated() {
            task.pinOrder = index + 1
            task.isPinned = true
        }
    }

    private static func nextAvailablePinOrder(in sectionID: UUID, tasks: [TaskItem]) -> Int {
        let usedOrders = Set(
            tasks
                .filter { $0.sectionID == sectionID && $0.isPinned && !$0.isDone }
                .compactMap(\.pinOrder)
        )

        for candidate in 1...maxPinnedPerSection where !usedOrders.contains(candidate) {
            return candidate
        }

        return maxPinnedPerSection
    }

    private static func moveItems<T>(_ items: inout [T], from source: IndexSet, to destination: Int) {
        let sourceIndexes = source.sorted()
        let movingItems = sourceIndexes.map { items[$0] }

        for index in sourceIndexes.sorted(by: >) {
            items.remove(at: index)
        }

        let adjustedDestination = destination - sourceIndexes.filter { $0 < destination }.count
        var insertionIndex = max(0, min(adjustedDestination, items.count))

        for item in movingItems {
            items.insert(item, at: insertionIndex)
            insertionIndex += 1
        }
    }

    private static func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.kind)
        #endif
    }
}
