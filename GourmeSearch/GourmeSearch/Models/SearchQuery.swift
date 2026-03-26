import Foundation

struct SearchQuery: Hashable {
    let latitude: Double
    let longitude: Double
    let range: Int
    let keyword: String
}
