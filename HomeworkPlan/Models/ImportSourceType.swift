import Foundation

enum ImportSourceType: String, Codable, CaseIterable {
    case screenshot
    case pasted
    case manual
    case recurring

    var displayName: String {
        switch self {
        case .screenshot:
            return "截图"
        case .pasted:
            return "粘贴"
        case .manual:
            return "手动"
        case .recurring:
            return "重复"
        }
    }
}
