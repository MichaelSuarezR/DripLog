
import Foundation

enum OutfitVisibility: CaseIterable, Sendable {
    case privateProfile
    case friends
    case publicProfile

    var title: String {
        switch self {
        case .privateProfile: return "private"
        case .friends:        return "friends"
        case .publicProfile:  return "public"
        }
    }

    init?(title: String) {
        switch title {
        case "private": self = .privateProfile
        case "friends": self = .friends
        case "public":  self = .publicProfile
        default:        return nil
        }
    }
}
