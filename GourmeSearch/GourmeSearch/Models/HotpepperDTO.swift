import Foundation

//以下json→Swiftの変換処理

struct HotpepperAPIResponse: Decodable {
    let results: ResultsDTO
}

struct ResultsDTO: Decodable {
    let resultsAvailable: Int
    let resultsReturned: Int
    let resultsStart: Int
    let shops: [ShopDTO]

    enum CodingKeys: String, CodingKey {
        case resultsAvailable = "results_available"
        case resultsReturned = "results_returned"
        case resultsStart = "results_start"
        case shops = "shop"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resultsAvailable = try container.decodeLossyInt(forKey: .resultsAvailable)
        resultsReturned = try container.decodeLossyInt(forKey: .resultsReturned)
        resultsStart = try container.decodeLossyInt(forKey: .resultsStart)
        shops = try container.decode([ShopDTO].self, forKey: .shops)
    }
}

struct ShopDTO: Decodable {
    let id: String
    let name: String
    let address: String?
    let mobileAccess: String?
    let lat: Double?
    let lng: Double?
    let open: String?
    let logoImage: String?
    let photo: PhotoDTO?
    let urls: URLsDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case mobileAccess = "mobile_access"
        case lat
        case lng
        case open
        case logoImage = "logo_image"
        case photo
        case urls
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        mobileAccess = try container.decodeIfPresent(String.self, forKey: .mobileAccess)
        lat = try container.decodeLossyDoubleIfPresent(forKey: .lat)
        lng = try container.decodeLossyDoubleIfPresent(forKey: .lng)
        open = try container.decodeIfPresent(String.self, forKey: .open)
        logoImage = try container.decodeIfPresent(String.self, forKey: .logoImage)
        photo = try container.decodeIfPresent(PhotoDTO.self, forKey: .photo)
        urls = try container.decodeIfPresent(URLsDTO.self, forKey: .urls)
    }
}

struct PhotoDTO: Decodable {
    let pc: PhotoPCDTO
}

struct PhotoPCDTO: Decodable {
    let large: String?
    let medium: String?
    let small: String?

    enum CodingKeys: String, CodingKey {
        case large = "l"
        case medium = "m"
        case small = "s"
    }
}

struct URLsDTO: Decodable {
    let pc: String?
}

//型揺れを防ぐ処理 だめなら次を試す   試す手順: Int >> String→Int変換 >> String→Double(無理やり数値化) >> 最終的にnil
private extension KeyedDecodingContainer {
    func decodeLossyInt(forKey key: KeyedDecodingContainer<K>.Key) throws -> Int {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }

        if let stringValue = try? decode(String.self, forKey: key),
           let intValue = Int(stringValue) {
            return intValue
        }

        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Int or numeric String for \(key.stringValue)"
            )
        )
    }

    func decodeLossyDoubleIfPresent(forKey key: KeyedDecodingContainer<K>.Key) throws -> Double? {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}
