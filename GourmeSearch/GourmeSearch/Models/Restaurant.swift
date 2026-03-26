import Foundation

struct Restaurant: Identifiable, Hashable {
    let id: String
    let name: String
    let access: String
    let thumbnailURL: URL?
    let imageURL: URL?
    let address: String
    let openHours: String
    let shopURL: URL?
    let latitude: Double?
    let longitude: Double?
}
