import SwiftUI
//店舗詳細View
struct RestaurantDetailView: View {
    let restaurant: Restaurant

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CachedRemoteImage(url: restaurant.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 220)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(restaurant.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    DetailRow(title: "住所", value: restaurant.address)
                    DetailRow(title: "営業時間", value: restaurant.openHours)
                    DetailRow(title: "アクセス", value: restaurant.access)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    if let shopURL = restaurant.shopURL {
                        Link("店舗ページを開く", destination: shopURL)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("店舗詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mapsURL(for address: String) -> URL? {
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "http://maps.apple.com/?q=\(encoded)")
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

#Preview {
    NavigationStack {
        RestaurantDetailView(
            restaurant: Restaurant(
                id: "preview",
                name: "プレビュー店舗",
                access: "渋谷駅 徒歩5分",
                thumbnailURL: nil,
                imageURL: nil,
                address: "東京都渋谷区1-1-1",
                openHours: "11:00-23:00",
                shopURL: nil,
                latitude: nil,
                longitude: nil
            )
        )
    }
}
