import SwiftUI
import WidgetKit
import SwiftData

struct WidgetTaskSnapshot: Hashable {
    let id: UUID
    let text: String
}

struct BucketEntry: TimelineEntry {
    let date: Date
    let sectionID: UUID?
    let sectionName: String
    let tasks: [WidgetTaskSnapshot]
    let routeURL: URL
}

struct BucketTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BucketEntry {
        BucketEntry(
            date: .now,
            sectionID: UUID(),
            sectionName: "今日",
            tasks: [
                WidgetTaskSnapshot(id: UUID(), text: "波の音を聴く"),
                WidgetTaskSnapshot(id: UUID(), text: "散歩する")
            ],
            routeURL: AppRoute.dashboard.url
        )
    }

    func snapshot(for configuration: BucketWidgetIntent, in context: Context) async -> BucketEntry {
        makeEntry(for: configuration.section?.id)
    }

    func timeline(for configuration: BucketWidgetIntent, in context: Context) async -> Timeline<BucketEntry> {
        let entry = makeEntry(for: configuration.section?.id)
        let nextDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextDate))
    }

    private func makeEntry(for requestedSectionID: UUID?) -> BucketEntry {
        do {
            let container = try SharedStore.makeContainer()
            let context = ModelContext(container)

            let sections = try context.fetch(FetchDescriptor<TaskSection>()).sorted {
                if $0.orderIndex != $1.orderIndex {
                    return $0.orderIndex < $1.orderIndex
                }
                return $0.createdAt < $1.createdAt
            }

            let selectedSection: TaskSection?
            if let requestedSectionID {
                selectedSection = sections.first(where: { $0.id == requestedSectionID })
                if selectedSection == nil {
                    return BucketEntry(
                        date: Date(),
                        sectionID: nil,
                        sectionName: WidgetConstants.missingSectionText,
                        tasks: [],
                        routeURL: AppRoute.dashboard.url
                    )
                }
            } else {
                selectedSection = sections.first
            }

            guard let section = selectedSection else {
                return BucketEntry(
                    date: Date(),
                    sectionID: nil,
                    sectionName: WidgetConstants.missingSectionText,
                    tasks: [],
                    routeURL: AppRoute.dashboard.url
                )
            }

            let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
            let tasks = allTasks
                .filter { $0.sectionID == section.id && !$0.isDone }
                .sorted(by: taskSort)
                .prefix(4)
                .map { WidgetTaskSnapshot(id: $0.id, text: $0.text) }

            return BucketEntry(
                date: Date(),
                sectionID: section.id,
                sectionName: section.name,
                tasks: Array(tasks),
                routeURL: section.deepLinkURL
            )
        } catch {
            return BucketEntry(
                date: Date(),
                sectionID: nil,
                sectionName: WidgetConstants.missingSectionText,
                tasks: [],
                routeURL: AppRoute.dashboard.url
            )
        }
    }

    private func taskSort(lhs: TaskItem, rhs: TaskItem) -> Bool {
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
}

struct BucketWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetConstants.kind,
            intent: BucketWidgetIntent.self,
            provider: BucketTimelineProvider()
        ) { entry in
            BucketWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NaniYaru⁉︎")
        .description("選択したカテゴリの上位タスクを表示")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct BucketWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BucketEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            case .accessoryRectangular:
                rectangularView
            case .accessoryInline:
                inlineView
            default:
                smallView
            }
        }
        .widgetURL(entry.routeURL)
    }

    private var accentColor: Color {
        guard let sectionID = entry.sectionID else {
            return Color(red: 0.15, green: 0.35, blue: 0.34)
        }
        return TaskSectionPalette.accentColor(for: sectionID)
    }

    private var surfaceColor: Color {
        guard let sectionID = entry.sectionID else {
            return Color(red: 0.95, green: 0.95, blue: 0.95)
        }
        return TaskSectionPalette.surfaceColor(for: sectionID)
    }

    private var displayedTasksSmall: [WidgetTaskSnapshot] {
        Array(entry.tasks.prefix(2))
    }

    private var displayedTasksMedium: [WidgetTaskSnapshot] {
        Array(entry.tasks.prefix(4))
    }

    private var displayedTasksRectangular: [WidgetTaskSnapshot] {
        Array(entry.tasks.prefix(2))
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(fontSize: 15)
            widgetTaskLines(displayedTasksSmall, lineLimit: 1)
            Spacer(minLength: 0)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(fontSize: 17)
            widgetTaskLines(displayedTasksMedium, lineLimit: 1)
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.sectionName)
                .font(.system(.caption, design: .rounded, weight: .semibold))
            widgetTaskLines(displayedTasksRectangular, lineLimit: 1, bulletPrefix: "・")
            Spacer(minLength: 0)
        }
    }

    private var inlineView: some View {
        let firstText = entry.tasks.first?.text ?? WidgetConstants.emptyText
        return Text("\(entry.sectionName): \(firstText)")
            .lineLimit(1)
    }

    private func header(fontSize: CGFloat) -> some View {
        Text(entry.sectionName)
            .font(.custom("Marker Felt", size: fontSize))
            .foregroundStyle(accentColor)
    }

    private func widgetTaskLines(_ tasks: [WidgetTaskSnapshot], lineLimit: Int, bulletPrefix: String = "•") -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if tasks.isEmpty {
                Text(WidgetConstants.emptyText)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks, id: \.id) { task in
                    Text("\(bulletPrefix) \(task.text)")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .lineLimit(lineLimit)
                }
            }
        }
    }

    private var widgetBackground: some View {
        LinearGradient(
            colors: [
                surfaceColor,
                Color.white.opacity(0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
