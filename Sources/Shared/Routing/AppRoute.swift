import Foundation

enum AppRoute: Equatable {
    case dashboard
    case section(UUID)

    static func from(url: URL) -> AppRoute? {
        guard url.scheme?.lowercased() == "naniyaru" else {
            return nil
        }

        guard let host = url.host?.lowercased() else {
            return nil
        }

        if host == "dashboard" {
            return .dashboard
        }

        if host == "section",
           let rawID = url.pathComponents.dropFirst().first,
           let sectionID = UUID(uuidString: rawID) {
            return .section(sectionID)
        }

        return nil
    }

    var url: URL {
        switch self {
        case .dashboard:
            return URL(string: "naniyaru://dashboard")!
        case let .section(sectionID):
            return URL(string: "naniyaru://section/\(sectionID.uuidString.lowercased())")!
        }
    }
}
