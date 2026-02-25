import XCTest
import SwiftData
@testable import NaniYaru

final class TaskRepositoryTests: XCTestCase {
    func testBootstrapCreatesDefaultSections() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try TaskRepository.bootstrapIfNeeded(context: context)
        let sections = try context.fetch(FetchDescriptor<TaskSection>())

        XCTAssertEqual(TaskRepository.orderedSections(from: sections).map(\.name), TaskRepository.defaultSectionNames)
    }

    func testNormalizedSectionNameRejectsEmpty() {
        XCTAssertNil(TaskRepository.normalizedSectionName(from: "   \n"))
    }

    func testAddSectionRejectsDuplicateName() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        _ = try TaskRepository.addSection(name: "今日", context: context)

        XCTAssertThrowsError(try TaskRepository.addSection(name: "今日", context: context)) { error in
            guard case TaskRepositoryError.duplicateSectionName = error else {
                return XCTFail("Expected duplicateSectionName")
            }
        }
    }

    func testPinLimitIsEnforced() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let section = try TaskRepository.addSection(name: "今週", context: context)

        for index in 0..<4 {
            try TaskRepository.addTask(text: "task-\(index)", to: section, allTasks: try fetchTasks(context), context: context)
        }

        let tasks = try TaskRepository.orderedTasks(from: fetchTasks(context), in: section.id, includeDone: false)
        try TaskRepository.togglePin(for: tasks[0], allTasks: try fetchTasks(context), context: context)
        try TaskRepository.togglePin(for: tasks[1], allTasks: try fetchTasks(context), context: context)
        try TaskRepository.togglePin(for: tasks[2], allTasks: try fetchTasks(context), context: context)

        XCTAssertThrowsError(try TaskRepository.togglePin(for: tasks[3], allTasks: try fetchTasks(context), context: context)) { error in
            guard case TaskRepositoryError.pinLimitReached = error else {
                return XCTFail("Expected pinLimitReached")
            }
        }
    }

    func testToggleCompletionSetsDoneAtAndClearsPin() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let section = try TaskRepository.addSection(name: "今月", context: context)

        try TaskRepository.addTask(text: "test", to: section, allTasks: try fetchTasks(context), context: context)
        guard let task = try fetchTasks(context).first else {
            return XCTFail("Task missing")
        }

        try TaskRepository.togglePin(for: task, allTasks: try fetchTasks(context), context: context)
        XCTAssertTrue(task.isPinned)

        try TaskRepository.toggleCompletion(for: task, allTasks: try fetchTasks(context), context: context)
        XCTAssertTrue(task.isDone)
        XCTAssertNotNil(task.doneAt)
        XCTAssertFalse(task.isPinned)
        XCTAssertNil(task.pinOrder)

        try TaskRepository.toggleCompletion(for: task, allTasks: try fetchTasks(context), context: context)
        XCTAssertFalse(task.isDone)
        XCTAssertNil(task.doneAt)
    }

    func testMoveTaskAcrossSectionsUpdatesSectionID() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let today = try TaskRepository.addSection(name: "今日", context: context)
        let week = try TaskRepository.addSection(name: "今週", context: context)

        try TaskRepository.addTask(text: "migrate", to: today, allTasks: try fetchTasks(context), context: context)
        guard let task = try fetchTasks(context).first else {
            return XCTFail("Task missing")
        }

        try TaskRepository.moveTask(task, to: week, allTasks: try fetchTasks(context), context: context)

        XCTAssertEqual(task.sectionID, week.id)
    }

    func testSharedStoreUsesFixedFileName() {
        let baseURL = URL(fileURLWithPath: "/tmp/naniyaru")
        let url = SharedStore.storeURL(in: baseURL)

        XCTAssertEqual(url.lastPathComponent, "NaniYaru.store")
    }

    func testSetSectionOrderPersistsSpecifiedOrder() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let first = try TaskRepository.addSection(name: "A", context: context)
        let second = try TaskRepository.addSection(name: "B", context: context)
        let third = try TaskRepository.addSection(name: "C", context: context)

        let desiredOrder = [third.id, first.id, second.id]
        try TaskRepository.setSectionOrder(desiredOrder, in: [first, second, third], context: context)

        let saved = try context.fetch(FetchDescriptor<TaskSection>())
        XCTAssertEqual(TaskRepository.orderedSections(from: saved).map(\.id), desiredOrder)
    }

    private func fetchTasks(_ context: ModelContext) throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskItem>())
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([TaskSection.self, TaskItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
