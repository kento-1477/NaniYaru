import SwiftUI
import SwiftData

struct SectionDetailView: View {
    let sectionID: UUID

    @Environment(\.modelContext) private var modelContext
    @Query private var sections: [TaskSection]
    @Query private var allTasks: [TaskItem]

    @State private var draftTaskText = ""
    @State private var errorMessage: String?

    private var section: TaskSection? {
        sections.first(where: { $0.id == sectionID })
    }

    private var incompleteTasks: [TaskItem] {
        guard let section else {
            return []
        }
        return TaskRepository.orderedTasks(from: allTasks, in: section.id, includeDone: false)
    }

    private var doneCount: Int {
        guard let section else {
            return 0
        }
        return allTasks.filter { $0.sectionID == section.id && $0.isDone }.count
    }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            if let section {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        headerCard(section)
                        composerCard(section)

                        if incompleteTasks.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 8) {
                                ForEach(incompleteTasks, id: \.id) { task in
                                    taskRow(task, in: section)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
            } else {
                VStack(spacing: 8) {
                    Text("区分が見つかりません")
                        .font(.system(.headline, design: .rounded))
                    Text("ダッシュボードから区分を選び直してください")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
        }
        .navigationTitle(section?.name ?? "区分")
        .navigationBarTitleDisplayMode(.inline)
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

    private func headerCard(_ section: TaskSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.name)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("未完了 \(incompleteTasks.count)件 / 完了 \(doneCount)件")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(section.surfaceColor.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(section.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func composerCard(_ section: TaskSection) -> some View {
        HStack(spacing: 8) {
            TaskInputEditor(
                text: $draftTaskText,
                placeholder: "\(section.name)に追加"
            )

            Button("追加") {
                addTask(to: section)
            }
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .disabled(TaskRepository.normalizedText(from: draftTaskText) == nil)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }

    private var emptyState: some View {
        Text("いまはなし")
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
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
                Button("上へ") {
                    moveTask(task, by: -1, within: section)
                }
                Button("下へ") {
                    moveTask(task, by: 1, within: section)
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

    private func addTask(to section: TaskSection) {
        do {
            try TaskRepository.addTask(text: draftTaskText, to: section, allTasks: allTasks, context: modelContext)
            draftTaskText = ""
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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

    private func moveTask(_ task: TaskItem, by delta: Int, within section: TaskSection) {
        let orderedTasks = TaskRepository.orderedTasks(from: allTasks, in: section.id, includeDone: false)
        guard let index = orderedTasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }

        let targetIndex = index + delta
        guard targetIndex >= 0, targetIndex < orderedTasks.count else {
            return
        }

        let source = IndexSet(integer: index)
        let destination = delta > 0 ? targetIndex + 1 : targetIndex

        do {
            try TaskRepository.reorderTasks(in: section, tasks: allTasks, from: source, to: destination, context: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SectionDetailView(sectionID: UUID())
        .modelContainer(for: [TaskSection.self, TaskItem.self], inMemory: true)
}
