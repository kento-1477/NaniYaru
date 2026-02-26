import AppIntents

struct BucketWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "カテゴリを選択"
    static var description = IntentDescription("表示したいカテゴリを選びます")

    @Parameter(title: "カテゴリ")
    var section: TaskSectionEntity?

    init() {
        section = nil
    }
}
