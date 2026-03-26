import Foundation

enum HotpepperAPIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case badStatusCode(Int)
    case decodeError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが設定されていません。Build Settings の HOTPEPPER_API_KEY を設定してください。"
        case .invalidURL:
            return "検索URLの生成に失敗しました。"
        case .invalidResponse:
            return "サーバー応答が不正です。"
        case .badStatusCode(let code):
            return "API通信に失敗しました (status: \(code))。"
        case .decodeError:
            return "APIレスポンスの解析に失敗しました。"
        }
    }
}



struct SearchPage {
    let restaurants: [Restaurant]
    let nextStart: Int?
}

struct HotpepperAPIService {
    private let endpoint = "https://webservice.recruit.co.jp/hotpepper/gourmet/v1/"

    func resolveAPIKey() throws -> String {
        let candidateKeys = [
            "HOTPEPPER_API_KEY",
            "INFOPLIST_KEY_HOTPEPPER_API_KEY"
        ]

        for keyName in candidateKeys {
            let key = Bundle.main.object(forInfoDictionaryKey: keyName) as? String
            let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        throw HotpepperAPIError.missingAPIKey
    }

    //URL組み立て
    func makeSearchURL(query: SearchQuery, start: Int = 1) throws -> URL {
        let apiKey = try resolveAPIKey()
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "lat", value: String(query.latitude)),
            URLQueryItem(name: "lng", value: String(query.longitude)),
            URLQueryItem(name: "range", value: String(query.range)),
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "count", value: "100")
        ]

        let trimmedKeyword = query.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKeyword.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "keyword", value: trimmedKeyword))
        }

        guard let url = components?.url else {
            throw HotpepperAPIError.invalidURL
        }
        return url
    }
    //API呼び出し
    func fetchRawSearchData(query: SearchQuery, start: Int = 1) async throws -> Data {
        let url = try makeSearchURL(query: query, start: start)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HotpepperAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HotpepperAPIError.badStatusCode(httpResponse.statusCode)
        }

        return data
    }

    //APIから店情報を受取る
    func searchRestaurants(query: SearchQuery, start: Int = 1) async throws -> SearchPage {
        let data = try await fetchRawSearchData(query: query, start: start)

        let decoded: HotpepperAPIResponse
        do {
            decoded = try JSONDecoder().decode(HotpepperAPIResponse.self, from: data)
        } catch {
            throw HotpepperAPIError.decodeError
        }

        //Restaurant構造体にさっき受け取った店情報(decoded)の中身を入れ込む
        let restaurants = decoded.results.shops.map { shop in
            Restaurant(
                id: shop.id,
                name: shop.name,
                access: shop.mobileAccess ?? "アクセス情報なし",
                thumbnailURL: URL(string: shop.photo?.pc.small ?? shop.logoImage ?? ""),
                imageURL: URL(string: shop.photo?.pc.large ?? shop.photo?.pc.medium ?? shop.logoImage ?? ""),
                address: shop.address ?? "住所情報なし",
                openHours: shop.open ?? "営業時間情報なし",
                shopURL: URL(string: shop.urls?.pc ?? ""),
                latitude: shop.lat,
                longitude: shop.lng
            )
        }

        let available = decoded.results.resultsAvailable
        let returned = decoded.results.resultsReturned
        let currentStart = decoded.results.resultsStart
        let next = currentStart + returned
        let nextStart = next <= available ? next : nil

        return SearchPage(restaurants: restaurants, nextStart: nextStart)
    }
}
