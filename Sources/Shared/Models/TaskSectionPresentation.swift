import Foundation
import SwiftUI

extension TaskSection {
    var deepLinkURL: URL {
        AppRoute.section(id).url
    }

    var accentColor: Color {
        TaskSectionPalette.accentColor(for: id)
    }

    var surfaceColor: Color {
        TaskSectionPalette.surfaceColor(for: id)
    }
}

enum TaskSectionPalette {
    private static let accents: [Color] = [
        Color(red: 0.13, green: 0.63, blue: 0.61),
        Color(red: 0.21, green: 0.59, blue: 0.86),
        Color(red: 0.97, green: 0.54, blue: 0.34),
        Color(red: 0.44, green: 0.55, blue: 0.44),
        Color(red: 0.76, green: 0.46, blue: 0.71)
    ]

    private static let surfaces: [Color] = [
        Color(red: 0.86, green: 0.97, blue: 0.94),
        Color(red: 0.88, green: 0.95, blue: 1.0),
        Color(red: 1.0, green: 0.92, blue: 0.86),
        Color(red: 0.91, green: 0.95, blue: 0.89),
        Color(red: 0.96, green: 0.90, blue: 0.97)
    ]

    static func accentColor(for id: UUID) -> Color {
        let index = Int(abs(id.hashValue)) % accents.count
        return accents[index]
    }

    static func surfaceColor(for id: UUID) -> Color {
        let index = Int(abs(id.hashValue)) % surfaces.count
        return surfaces[index]
    }
}
