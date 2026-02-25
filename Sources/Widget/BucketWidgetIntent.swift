import AppIntents

struct BucketWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "区分を選択"
    static var description = IntentDescription("表示したい区分を選びます")

    @Parameter(title: "区分")
    var section: TaskSectionEntity?

    init() {
        section = nil
    }
}
