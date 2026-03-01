import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Binding var routeSectionID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query private var sections: [TaskSection]
    @Query private var allTasks: [TaskItem]

    @State private var navigationPath: [UUID] = []

    @State private var errorMessage: String?

    @State private var showAddTaskSheet = false
    @State private var addTaskText = ""
    @State private var addTaskSectionID: UUID?

    @State private var showAddSectionAlert = false
    @State private var newSectionName = ""

    @State private var renameSectionID: UUID?
    @State private var renameSectionName = ""

    @State private var deleteSectionID: UUID?
    @State private var sectionOrderDuringDrag: [UUID] = []
    @State private var activeDragPayload: String?
    @State private var sectionDropTargetID: UUID?

    private static let sectionDragPrefix = "section:"
    private static let taskDragPrefix = "task:"

    private var orderedSections: [TaskSection] {
        TaskRepository.orderedSections(from: sections)
    }

    private var orderedSectionIDs: [UUID] {
        orderedSections.map(\.id)
    }

    private var visibleSections: [TaskSection] {
        guard !sectionOrderDuringDrag.isEmpty else {
            return orderedSections
        }

        let sectionByID = Dictionary(uniqueKeysWithValues: orderedSections.map { ($0.id, $0) })
        let reordered = sectionOrderDuringDrag.compactMap { sectionByID[$0] }
        return reordered.count == orderedSections.count ? reordered : orderedSections
    }

    private var isSectionDragActive: Bool {
        guard let payload = activeDragPayload else {
            return false
        }
        return payload.hasPrefix(Self.sectionDragPrefix)
    }

    private var isTaskDragActive: Bool {
        guard let payload = activeDragPayload else {
            return false
        }
        return payload.hasPrefix(Self.taskDragPrefix)
    }

    private var selectedSectionForSheet: TaskSection? {
        guard let addTaskSectionID else {
            return nil
        }
        return orderedSections.first(where: { $0.id == addTaskSectionID })
    }

    private var addTaskDisabled: Bool {
        TaskRepository.normalizedText(from: addTaskText) == nil || selectedSectionForSheet == nil
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(visibleSections, id: \.id) { section in
                            sectionCard(section)
                        }

                        if visibleSections.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
            }
            .navigationDestination(for: UUID.self) { sectionID in
                SectionDetailView(sectionID: sectionID)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("NaniYaru⁉︎")
                        .font(.custom("Marker Felt", size: 30))
                        .foregroundStyle(Color(red: 0.15, green: 0.35, blue: 0.34))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        presentAddTaskSheet()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }

                    Menu {
                        Button("新しいカテゴリを作る") {
                            showAddSectionAlert = true
                        }
                        Button("カテゴリの並びを最初に戻す") {
                            moveAllSectionsToDefaultOrder()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                applyIncomingRoute(routeSectionID)
                syncSectionOrderWithModel()
            }
            .onChange(of: routeSectionID) { _, newValue in
                applyIncomingRoute(newValue)
            }
            .onChange(of: orderedSectionIDs) { _, _ in
                syncSectionOrderWithModel()
            }
        }
        .sheet(isPresented: $showAddTaskSheet) {
            addTaskSheet
        }
        .alert("カテゴリを追加", isPresented: $showAddSectionAlert) {
            TextField("カテゴリ名", text: $newSectionName)
            Button("追加") { addSection() }
            Button("キャンセル", role: .cancel) {
                newSectionName = ""
            }
        } message: {
            Text("1〜12文字で入力")
        }
        .alert("カテゴリ名を変更", isPresented: Binding(get: {
            renameSectionID != nil
        }, set: { presenting in
            if !presenting {
                renameSectionID = nil
                renameSectionName = ""
            }
        })) {
            TextField("カテゴリ名", text: $renameSectionName)
            Button("保存") {
                renameSection()
            }
            Button("キャンセル", role: .cancel) {
                renameSectionID = nil
                renameSectionName = ""
            }
        } message: {
            Text("1〜12文字で入力")
        }
        .confirmationDialog("カテゴリとタスクを削除します", isPresented: Binding(get: {
            deleteSectionID != nil
        }, set: { presenting in
            if !presenting {
                deleteSectionID = nil
            }
        }), titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                deleteSection()
            }
            Button("キャンセル", role: .cancel) {
                deleteSectionID = nil
            }
        }
        .alert("エラー", isPresented: Binding(get: {
            errorMessage != nil
        }, set: { presenting in
            if !presenting {
                errorMessage = nil
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.95, blue: 0.86),
                Color(red: 0.84, green: 0.95, blue: 0.91)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("カテゴリがありません")
                .font(.system(.headline, design: .rounded))
            Text("右上のメニューからカテゴリを追加")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func sectionCard(_ section: TaskSection) -> some View {
        let incompleteTasks = TaskRepository.orderedTasks(from: allTasks, in: section.id, includeDone: false)
        let doneCount = allTasks.filter { $0.sectionID == section.id && $0.isDone }.count
        let visibleTasks = Array(incompleteTasks.prefix(3))
        let hiddenCount = max(0, incompleteTasks.count - 3)
        let isDropTarget = sectionDropTargetID == section.id
        let isTaskDropTarget = isDropTarget && isTaskDragActive
        let strokeColor: Color = {
            if !isDropTarget {
                return Color.black.opacity(0.08)
            }
            if isSectionDragActive {
                return section.accentColor.opacity(0.78)
            }
            if isTaskDragActive {
                return section.accentColor.opacity(0.62)
            }
            return Color.black.opacity(0.08)
        }()
        let strokeWidth: CGFloat = isDropTarget ? (isSectionDragActive ? 2.4 : 2.0) : 1.0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("未完了 \(incompleteTasks.count)件 / 完了 \(doneCount)件")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Menu {
                    Button("名前を変更") {
                        renameSectionID = section.id
                        renameSectionName = section.name
                    }
                    Divider()
                    Button("削除", role: .destructive) {
                        deleteSectionID = section.id
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            if visibleTasks.isEmpty {
                Text("いまはなし")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(visibleTasks, id: \.id) { task in
                        taskRow(task, in: section)
                            .onDrag {
                                taskDragProvider(for: task.id)
                            }
                    }
                }
            }

            if hiddenCount > 0 {
                Text("他 \(hiddenCount) 件")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if isTaskDropTarget {
                Text("ここに移動")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(section.accentColor)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(section.surfaceColor.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            navigationPath.append(section.id)
        }
        .onDrag {
            sectionDragProvider(for: section.id)
        }
        .onDrop(
            of: [UTType.plainText.identifier],
            delegate: SectionCardDropDelegate(
                targetSectionID: section.id,
                sectionPrefix: Self.sectionDragPrefix,
                sectionOrderDuringDrag: $sectionOrderDuringDrag,
                activeDragPayload: $activeDragPayload,
                sectionDropTargetID: $sectionDropTargetID,
                commitSectionOrder: commitSectionOrderFromDrag,
                handleTaskDrop: handleTaskDrop,
                onDropCompleted: notifyDropCompleted
            )
        )
        .animation(.spring(response: 0.24, dampingFraction: 0.85), value: sectionOrderDuringDrag)
    }

    private func taskRow(_ task: TaskItem, in section: TaskSection) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                toggleDone(task)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? section.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.text)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(2)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .strikethrough(task.isDone, color: .secondary)

                if task.isPinned {
                    Text("PIN \(task.pinOrder ?? 0)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(section.accentColor)
                }
            }

            Spacer(minLength: 8)

            Menu {
                Button(task.isPinned ? "ピン解除" : "ピン留め") {
                    togglePin(task)
                }
                Divider()
                Button("削除", role: .destructive) {
                    deleteTask(task)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .padding(6)
                    .background(Circle().fill(Color.white.opacity(0.8)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private var addTaskSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("やりたいこと")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                TaskInputEditor(
                    text: $addTaskText,
                    placeholder: "タスクを入力"
                )

                Text("時間軸タグ")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                Text("タグをタップして追加先のカテゴリを選ぶ")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                if orderedSections.isEmpty {
                    Text("先にカテゴリを追加してください")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(orderedSections, id: \.id) { section in
                                sectionTag(section)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("タスク追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismissAddTaskSheet()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addTaskFromSheet()
                    }
                    .disabled(addTaskDisabled)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func sectionTag(_ section: TaskSection) -> some View {
        let isSelected = addTaskSectionID == section.id

        return Button {
            addTaskSectionID = section.id
        } label: {
            HStack(spacing: 6) {
                Text(section.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? section.accentColor : Color.primary)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? section.accentColor.opacity(0.22) : Color.white.opacity(0.82))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? section.accentColor : Color.black.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func applyIncomingRoute(_ sectionID: UUID?) {
        guard let sectionID else {
            navigationPath = []
            return
        }

        if orderedSections.contains(where: { $0.id == sectionID }) {
            navigationPath = [sectionID]
        }
    }

    private func presentAddTaskSheet() {
        guard !orderedSections.isEmpty else {
            errorMessage = "先にカテゴリを追加してください"
            return
        }

        if selectedSectionForSheet == nil {
            addTaskSectionID = orderedSections.first?.id
        }

        showAddTaskSheet = true
    }

    private func dismissAddTaskSheet() {
        showAddTaskSheet = false
        addTaskText = ""
    }

    private func addTaskFromSheet() {
        guard let section = selectedSectionForSheet else {
            errorMessage = "追加先のカテゴリを選択してください"
            return
        }

        do {
            try TaskRepository.addTask(text: addTaskText, to: section, allTasks: allTasks, context: modelContext)
            addTaskText = ""
            showAddTaskSheet = false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func addSection() {
        do {
            _ = try TaskRepository.addSection(name: newSectionName, context: modelContext)
            newSectionName = ""
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func renameSection() {
        guard let renameSectionID,
              let section = sections.first(where: { $0.id == renameSectionID }) else {
            return
        }

        do {
            try TaskRepository.renameSection(section, to: renameSectionName, context: modelContext)
            self.renameSectionID = nil
            self.renameSectionName = ""
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func deleteSection() {
        guard let deleteSectionID,
              let section = sections.first(where: { $0.id == deleteSectionID }) else {
            return
        }

        do {
            try TaskRepository.deleteSection(section, context: modelContext)
            self.deleteSectionID = nil

            if addTaskSectionID == deleteSectionID {
                addTaskSectionID = orderedSections.first(where: { $0.id != deleteSectionID })?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleDone(_ task: TaskItem) {
        do {
            try TaskRepository.toggleCompletion(for: task, allTasks: allTasks, context: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func togglePin(_ task: TaskItem) {
        do {
            try TaskRepository.togglePin(for: task, allTasks: allTasks, context: modelContext)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func deleteTask(_ task: TaskItem) {
        do {
            try TaskRepository.delete(task, allTasks: allTasks, context: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func notifyDropCompleted(isSectionDrop: Bool, success: Bool) {
        guard success else {
            return
        }

        #if canImport(UIKit)
        let style: UIImpactFeedbackGenerator.FeedbackStyle = isSectionDrop ? .medium : .light
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    private func syncSectionOrderWithModel() {
        sectionOrderDuringDrag = orderedSectionIDs
    }

    private func taskDragProvider(for taskID: UUID) -> NSItemProvider {
        makeDragProvider(payload: Self.taskDragPrefix + taskID.uuidString)
    }

    private func sectionDragProvider(for sectionID: UUID) -> NSItemProvider {
        if sectionOrderDuringDrag.count != orderedSectionIDs.count || sectionOrderDuringDrag.isEmpty {
            syncSectionOrderWithModel()
        }
        return makeDragProvider(payload: Self.sectionDragPrefix + sectionID.uuidString)
    }

    private func makeDragProvider(payload: String) -> NSItemProvider {
        activeDragPayload = payload

        let provider = NSItemProvider()
        provider.suggestedName = payload
        let data = Data(payload.utf8)
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.plainText.identifier,
            visibility: .all
        ) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    private func commitSectionOrderFromDrag() -> Bool {
        let currentSections = orderedSections
        guard !currentSections.isEmpty else {
            return false
        }

        let candidateOrder = sectionOrderDuringDrag.isEmpty ? currentSections.map(\.id) : sectionOrderDuringDrag

        do {
            try TaskRepository.setSectionOrder(candidateOrder, in: currentSections, context: modelContext)
            syncSectionOrderWithModel()
            return true
        } catch {
            errorMessage = error.localizedDescription
            syncSectionOrderWithModel()
            return false
        }
    }

    private func handleTaskDrop(payload: String, targetSectionID: UUID) -> Bool {
        guard let targetSection = orderedSections.first(where: { $0.id == targetSectionID }),
              let taskID = taskID(fromDropPayload: payload),
              let task = allTasks.first(where: { $0.id == taskID }) else {
            return false
        }

        do {
            try TaskRepository.moveTask(task, to: targetSection, allTasks: allTasks, context: modelContext)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    private func taskID(fromDropPayload payload: String) -> UUID? {
        if payload.hasPrefix(Self.taskDragPrefix) {
            let rawID = String(payload.dropFirst(Self.taskDragPrefix.count))
            return UUID(uuidString: rawID)
        }

        return UUID(uuidString: payload)
    }

    private func moveAllSectionsToDefaultOrder() {
        let current = orderedSections
        let expected = TaskRepository.defaultSectionNames

        for section in current {
            if let index = expected.firstIndex(of: section.name) {
                section.orderIndex = Double(index)
            } else {
                section.orderIndex += 100
            }
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SectionCardDropDelegate: DropDelegate {
    let targetSectionID: UUID
    let sectionPrefix: String
    @Binding var sectionOrderDuringDrag: [UUID]
    @Binding var activeDragPayload: String?
    @Binding var sectionDropTargetID: UUID?
    let commitSectionOrder: () -> Bool
    let handleTaskDrop: (_ payload: String, _ targetSectionID: UUID) -> Bool
    let onDropCompleted: (_ isSectionDrop: Bool, _ success: Bool) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText.identifier])
    }

    func dropEntered(info: DropInfo) {
        sectionDropTargetID = targetSectionID

        guard let payload = activeDragPayload,
              payload.hasPrefix(sectionPrefix) else {
            return
        }

        let rawID = String(payload.dropFirst(sectionPrefix.count))
        guard let sourceSectionID = UUID(uuidString: rawID),
              sourceSectionID != targetSectionID,
              let sourceIndex = sectionOrderDuringDrag.firstIndex(of: sourceSectionID),
              let targetIndex = sectionOrderDuringDrag.firstIndex(of: targetSectionID) else {
            return
        }

        let destination = sourceIndex < targetIndex ? targetIndex + 1 : targetIndex
        if sourceIndex != destination {
            withAnimation(.snappy(duration: 0.18, extraBounce: 0.08)) {
                sectionOrderDuringDrag.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destination)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        sectionDropTargetID = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            sectionDropTargetID = nil
            activeDragPayload = nil
        }

        guard let payload = activeDragPayload else {
            return false
        }

        let isSectionDrop = payload.hasPrefix(sectionPrefix)
        let success: Bool
        if isSectionDrop {
            success = commitSectionOrder()
        } else {
            success = handleTaskDrop(payload, targetSectionID)
        }

        onDropCompleted(isSectionDrop, success)
        return success
    }
}

#Preview {
    ContentView(routeSectionID: .constant(nil))
        .modelContainer(for: [TaskSection.self, TaskItem.self], inMemory: true)
}
