import SwiftUI

struct SearchResultsView: View {
    let restaurants: [Restaurant]
    @Binding var selectedRestaurant: Restaurant?

    var body: some View {
        NavigationStack {
            List {
                if restaurants.isEmpty {
                    Text("検索結果がありません。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(restaurants) { restaurant in
                        Button {
                            selectedRestaurant = restaurant
                        } label: {
                            RestaurantRow(restaurant: restaurant)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("検索結果")
            .navigationDestination(item: $selectedRestaurant) { restaurant in
                RestaurantDetailView(restaurant: restaurant)
            }
        }
    }
}

private struct RestaurantRow: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedRemoteImage(url: restaurant.thumbnailURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(restaurant.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(restaurant.access)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SearchResultsView(restaurants: [], selectedRestaurant: .constant(nil))
}
