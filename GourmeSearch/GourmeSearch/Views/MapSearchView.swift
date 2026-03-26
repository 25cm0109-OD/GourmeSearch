import MapKit
import SwiftUI
import Combine
import UIKit

private struct LiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 14
    var tint: Color = .white
    var tintOpacity: CGFloat = 0.08
    var shadowOpacity: CGFloat = 0.18

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(tint.opacity(tintOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.9)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(shadowOpacity), radius: 10, y: 4)
    }
}

private extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = 14,
        tint: Color = .white,
        tintOpacity: CGFloat = 0.08,
        shadowOpacity: CGFloat = 0.18
    ) -> some View {
        modifier(
            LiquidGlassCard(
                cornerRadius: cornerRadius,
                tint: tint,
                tintOpacity: tintOpacity,
                shadowOpacity: shadowOpacity
            )
        )
    }
}

//サジェスト機能
private struct PlaceSuggestion: Identifiable, Hashable {
    let title: String
    let subtitle: String
    var id: String { "\(title)|\(subtitle)" }
}

//検索補完機能
@MainActor
private final class LocalSearchCompleterService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [PlaceSuggestion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.prefix(8).map {
            PlaceSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        suggestions = []
    }
}

struct MapSearchView: View {
    //モーダルviewの高さ指標
    private enum SheetLevel {
        case low
        case medium
        case high
    }

    private let radiusMetersOptions = [200, 500, 1000, 2000, 3000]
    private let thumbnailPinMaxCount = 20
    private let cameraDebounceNanoseconds: UInt64 = 120_000_000

    @StateObject private var locationService = LocationService()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var shopKeyword = ""
    @State private var geocodeErrorMessage: String?
    @State private var selectedRadiusIndex = 2
    @State private var restaurants: [Restaurant] = []
    @State private var isSearching = false
    @State private var isResultSheetPresented = false
    @State private var selectedRestaurant: Restaurant?
    @State private var selectedMapRestaurantID: String?
    @State private var sheetLevel: SheetLevel = .low
    @State private var selectedPlaceName: String?
    @State private var selectedPlaceCoordinate: CLLocationCoordinate2D?
    @State private var userPinnedCoordinate: CLLocationCoordinate2D?
    @State private var placeSearchText = ""
    @State private var isPlaceOverlayPresented = false
    @State private var shouldSelectAllPlaceText = false
    @State private var shouldSelectAllShopKeywordText = false
    @State private var shouldSearchAfterCurrentLocationUpdate = false
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var cameraRegionDebounceTask: Task<Void, Never>?
    @StateObject private var completerService = LocalSearchCompleterService()
    @FocusState private var isPlaceTextFieldFocused: Bool
    @FocusState private var isShopKeywordFieldFocused: Bool

    private let apiService = HotpepperAPIService()

    var body: some View {
        ZStack(alignment: .top) {
            //マップUI
            MapReader { proxy in
                Map(position: $position, selection: $selectedMapRestaurantID) {
                    UserAnnotation()
                    if let pinned = userPinnedCoordinate {
                        Annotation("検索地点", coordinate: pinned) {
                            Button {
                                userPinnedCoordinate = nil
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                    Text("検索地点")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ForEach(restaurants) { restaurant in
                        if let latitude = restaurant.latitude,
                           let longitude = restaurant.longitude {
                            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                            if thumbnailPinIDs.contains(restaurant.id) {
                                Annotation(restaurant.name, coordinate: coordinate) {
                                    Button {
                                        selectedRestaurant = restaurant
                                    } label: {
                                        CachedRemoteImage(url: restaurant.thumbnailURL) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Color.gray.opacity(0.2)
                                        }
                                        .frame(width: 38, height: 38)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 2)
                                        )
                                        .shadow(radius: 2)
                                    }
                                }
                            } else {
                                Marker(restaurant.name, coordinate: coordinate)
                                    .tint(.red)
                                    .tag(restaurant.id)
                            }
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                        .onEnded { value in
                            guard case .second(true, let drag?) = value else { return }
                            if let coordinate = proxy.convert(drag.location, from: .local) {
                                userPinnedCoordinate = coordinate
                                selectedPlaceCoordinate = coordinate
                                selectedPlaceName = "手動ピン地点"
                                geocodeErrorMessage = nil
                            }
                        }
                )
                .onMapCameraChange(frequency: .continuous) { context in
                    scheduleVisibleRegionUpdate(context.region)
                }
            }

            //地点検索UI
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Button {
                        openPlaceOverlay(selectAll: selectedPlaceName != nil)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(selectedPlaceName ?? "地点未選択")
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        clearSelectedPlace()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPlaceName == nil && selectedPlaceCoordinate == nil && userPinnedCoordinate == nil)
                    .opacity((selectedPlaceName == nil && selectedPlaceCoordinate == nil && userPinnedCoordinate == nil) ? 0.35 : 1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .liquidGlassCard(cornerRadius: 12)

                //店名検索UI
                HStack(spacing: 6) {
                    TextField("店名・キーワードで検索", text: $shopKeyword)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .focused($isShopKeywordFieldFocused)
                        .onTapGesture {
                            if !shopKeyword.isEmpty {
                                shouldSelectAllShopKeywordText = true
                            } else if selectedPlaceCoordinate == nil {
                                openPlaceOverlay(selectAll: false)
                            }
                        }
                        .onSubmit {
                            searchByShopKeyword()
                        }

                    Button {
                        isShopKeywordFieldFocused = false
                        searchByPinnedOrCameraCenter()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .liquidGlassCard(cornerRadius: 12)
                
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        
        //半径選択ボタンUI
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                
                Button {
                    selectedRadiusIndex = (selectedRadiusIndex + 1) % radiusMetersOptions.count
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.and.ellipse.circle.fill")
                            .font(.title3)
                        Text("\(radiusMetersOptions[selectedRadiusIndex])m")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.blue)
                    .liquidGlassCard(cornerRadius: 12, tint: .blue, tintOpacity: 0.07, shadowOpacity: 0.16)
                }

                Button {
                    searchByMapCenter()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "scope")
                            .font(.title3)
                        Text("中心検索")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.green)
                    .liquidGlassCard(cornerRadius: 12, tint: .green, tintOpacity: 0.07, shadowOpacity: 0.16)
                }

            }
            .padding(.trailing, 16)
            .padding(.bottom, 140)
        }
        
        
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if isSearching {
                    ProgressView("検索中...")
                        .font(.footnote)
                }

                if let geocodeErrorMessage {
                    Text(geocodeErrorMessage)
                        .font(.footnote)
                        .padding(8)
                        .liquidGlassCard(cornerRadius: 10, tint: .red, tintOpacity: 0.12, shadowOpacity: 0.12)
                }
            }
            .padding(.bottom, 20)
        }
        //地点検索UI
        .overlay(alignment: .top) {
            if isPlaceOverlayPresented {
                ZStack(alignment: .top) {
                    // 背景の暗転（タップで閉じる）
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isPlaceOverlayPresented = false
                            completerService.suggestions = []
                        }

                    VStack(spacing: 0) {
                        // --- ヘッダー部分 ---
                        HStack {
                            Text("地点を検索")
                                .font(.title3)
                                .bold()
                            Spacer()
                            Button {
                                isPlaceOverlayPresented = false
                                completerService.suggestions = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                        // 検索バー
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("地点名を入力", text: $placeSearchText)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .focused($isPlaceTextFieldFocused)
                                .onChange(of: placeSearchText) { _, newValue in
                                    completerService.update(query: newValue)
                                }
                            
                            if !placeSearchText.isEmpty {
                                Button { placeSearchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .liquidGlassCard(cornerRadius: 12, tint: .white, tintOpacity: 0.03, shadowOpacity: 0.08)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        //検索結果リスト
                        ScrollView {
                            VStack(spacing: 0) {
                                Button {
                                    selectCurrentLocation()
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                            .frame(width: 40, height: 40)
                                            .background(Color.green.gradient)
                                            .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("現在地")
                                                .font(.body)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.primary)
                                            Text("GPSで現在地を使用して検索")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                }
                                Divider()
                                    .padding(.leading, 70)

                                if !completerService.suggestions.isEmpty {
                                    ForEach(completerService.suggestions.prefix(8)) { suggestion in
                                        Button {
                                            selectPlace(suggestion: suggestion)
                                        } label: {
                                            HStack(spacing: 14) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 40, height: 40)
                                                    .background(Color.blue.gradient)
                                                    .clipShape(Circle())

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(suggestion.title)
                                                        .font(.body)
                                                        .fontWeight(.medium)
                                                        .foregroundStyle(.primary)
                                                        .lineLimit(1)

                                                    if !suggestion.subtitle.isEmpty {
                                                        Text(suggestion.subtitle)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(1)
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 16)
                                        }

                                        Divider()
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 400)

                        if completerService.suggestions.isEmpty && placeSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // 何も入力されていない時の表示
                            VStack(spacing: 8) {
                                Image(systemName: "map.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.quaternary)
                                Text("駅名、住所、施設名などを入力してください")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .liquidGlassCard(cornerRadius: 24, tint: .white, tintOpacity: 0.07, shadowOpacity: 0.2)
                    .padding(.horizontal, 12)
                    .padding(.top, 54)
                }
                .transition(.move(edge: .top).combined(with: .opacity)) // アニメーション
            }
        }
        .onAppear {
            locationService.requestCurrentLocation()
        }
        .onDisappear {
            cameraRegionDebounceTask?.cancel()
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
        .onChange(of: isPlaceOverlayPresented) { _, isPresented in
            guard isPresented else { return }
            isPlaceTextFieldFocused = true
            if shouldSelectAllPlaceText {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.selectAll(_:)),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
        .onChange(of: isShopKeywordFieldFocused) { _, isFocused in
            guard isFocused else { return }
            guard shouldSelectAllShopKeywordText else { return }
            shouldSelectAllShopKeywordText = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.selectAll(_:)),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        }
        .sheet(isPresented: $isResultSheetPresented) {
            SearchResultsView(
                restaurants: restaurants,
                selectedRestaurant: $selectedRestaurant
            )
                .presentationDetents(
                    [.height(120), .medium, .large],
                    selection: detentBinding
                )
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(20)
                .interactiveDismissDisabled()
        }
        .onChange(of: selectedRestaurant) { _, newValue in
            if newValue != nil {
                sheetLevel = .high
            } else {
                sheetLevel = .medium
            }
        }
        .onChange(of: selectedMapRestaurantID) { _, newID in
            guard let newID else { return }
            guard let tappedRestaurant = restaurants.first(where: { $0.id == newID }) else { return }
            selectedRestaurant = tappedRestaurant
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            guard shouldSearchAfterCurrentLocationUpdate else { return }
            guard let coordinate = newLocation?.coordinate else { return }
            shouldSearchAfterCurrentLocationUpdate = false
            applySelectedPlace(
                coordinate: coordinate,
                displayName: "現在地",
                shouldSearchImmediately: true
            )
        }
    }

    private func searchByShopKeyword() {
        let anchor = selectedPlaceCoordinate ?? locationService.currentLocation?.coordinate
        guard let coordinate = anchor else {
            geocodeErrorMessage = "地点を選択するか、現在地取得後に検索してください。"
            return
        }

        Task {
            await searchRestaurants(at: coordinate, keyword: shopKeyword)
        }
    }

    private func searchByPinnedOrCameraCenter() {
        guard let coordinate = userPinnedCoordinate ?? visibleRegion?.center else {
            geocodeErrorMessage = "地図を表示して中心地点を確定してから検索してください。"
            return
        }
        dismissKeyboard()
        Task {
            await searchRestaurants(at: coordinate, keyword: shopKeyword)
        }
    }

    private func searchByMapCenter() {
        guard let coordinate = visibleRegion?.center else {
            geocodeErrorMessage = "地図の中心地点を確定してから検索してください。"
            return
        }
        dismissKeyboard()
        Task {
            await searchRestaurants(at: coordinate, keyword: shopKeyword)
        }
    }

    //変換した座標を使って店の情報を取得(非同期処理)
    private func searchRestaurants(at coordinate: CLLocationCoordinate2D, keyword: String) async {
        guard !isSearching else { return }
        isSearching = true
        geocodeErrorMessage = nil
        defer { isSearching = false }

        let query = SearchQuery(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            range: selectedRadiusIndex + 1,
            keyword: keyword
        )

        do {
            let page = try await apiService.searchRestaurants(query: query, start: 1)
            restaurants = page.restaurants
            isResultSheetPresented = true
            sheetLevel = .medium
            fitMapToRestaurants()
        } catch {
            geocodeErrorMessage = error.localizedDescription
        }
    }

    private func selectPlace(suggestion: PlaceSuggestion) {
        let query = suggestion.subtitle.isEmpty
            ? suggestion.title
            : "\(suggestion.title) \(suggestion.subtitle)"
        let displayName = suggestion.subtitle.isEmpty
            ? suggestion.title
            : "\(suggestion.title), \(suggestion.subtitle)"

        Task {
            do {
                let coordinate = try await geocodeCoordinate(for: query)
                applySelectedPlace(
                    coordinate: coordinate,
                    displayName: displayName,
                    shouldSearchImmediately: false
                )
            } catch {
                geocodeErrorMessage = error.localizedDescription
            }
        }
    }

    private func selectCurrentLocation() {
        if let coordinate = locationService.currentLocation?.coordinate {
            shouldSearchAfterCurrentLocationUpdate = false
            applySelectedPlace(
                coordinate: coordinate,
                displayName: "現在地",
                shouldSearchImmediately: true
            )
            return
        }

        shouldSearchAfterCurrentLocationUpdate = true
        locationService.requestCurrentLocation()
    }

    //店がたくさん見つかった時にズーム倍率を調整する
    private func fitMapToRestaurants() {
        let coords = restaurants.compactMap { restaurant -> CLLocationCoordinate2D? in
            guard let lat = restaurant.latitude, let lng = restaurant.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard !coords.isEmpty else { return }

        let minLat = coords.map(\.latitude).min() ?? coords[0].latitude
        let maxLat = coords.map(\.latitude).max() ?? coords[0].latitude
        let minLng = coords.map(\.longitude).min() ?? coords[0].longitude
        let maxLng = coords.map(\.longitude).max() ?? coords[0].longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let latDelta = max(0.01, (maxLat - minLat) * 1.4)
        let lngDelta = max(0.01, (maxLng - minLng) * 1.4)

        position = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
            )
        )
    }

    //地名→緯度経度 に変換
    private func geocodeCoordinate(for query: String) async throws -> CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            guard let request = MKGeocodingRequest(addressString: query) else {
                throw NSError(
                    domain: "MapSearchView",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "地点が見つかりませんでした。"]
                )
            }

            let mapItems = try await request.mapItems
            guard let coordinate = mapItems.first?.location.coordinate else {
                throw NSError(
                    domain: "MapSearchView",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "地点が見つかりませんでした。"]
                )
            }
            return coordinate
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        guard let mapItem = response.mapItems.first else {
            throw NSError(
                domain: "MapSearchView",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "地点が見つかりませんでした。"]
            )
        }
        return mapItem.location.coordinate
    }

    private var detentBinding: Binding<PresentationDetent> {
        Binding(
            get: {
                switch sheetLevel {
                case .low:
                    return .height(120)
                case .medium:
                    return .medium
                case .high:
                    return .large
                }
            },
            set: { newValue in
                switch newValue {
                case .large:
                    sheetLevel = .high
                case .medium:
                    sheetLevel = .medium
                default:
                    sheetLevel = .low
                }
            }
        )
    }

    private var thumbnailPinIDs: Set<String> {
        let candidates: [Restaurant]
        if let region = visibleRegion {
            candidates = restaurants.filter { restaurant in
                guard let lat = restaurant.latitude, let lng = restaurant.longitude else { return false }
                return contains(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    in: region
                )
            }
        } else {
            candidates = restaurants
        }
        guard candidates.count <= thumbnailPinMaxCount else {
            return []
        }
        return Set(candidates.prefix(thumbnailPinMaxCount).map(\.id))
    }

    private func contains(coordinate: CLLocationCoordinate2D, in region: MKCoordinateRegion) -> Bool {
        let latMin = region.center.latitude - (region.span.latitudeDelta / 2)
        let latMax = region.center.latitude + (region.span.latitudeDelta / 2)
        let lngMin = region.center.longitude - (region.span.longitudeDelta / 2)
        let lngMax = region.center.longitude + (region.span.longitudeDelta / 2)
        return (latMin...latMax).contains(coordinate.latitude)
            && (lngMin...lngMax).contains(coordinate.longitude)
    }

    private func openPlaceOverlay(selectAll: Bool) {
        shouldSelectAllPlaceText = selectAll
        isPlaceOverlayPresented = true
        placeSearchText = selectedPlaceName ?? ""
        completerService.update(query: placeSearchText)
    }

    private func clearSelectedPlace() {
        selectedPlaceCoordinate = nil
        selectedPlaceName = nil
        userPinnedCoordinate = nil
        placeSearchText = ""
        shouldSearchAfterCurrentLocationUpdate = false
        geocodeErrorMessage = nil
    }

    private func applySelectedPlace(
        coordinate: CLLocationCoordinate2D,
        displayName: String,
        shouldSearchImmediately: Bool
    ) {
        selectedPlaceCoordinate = coordinate
        selectedPlaceName = displayName
        userPinnedCoordinate = coordinate
        placeSearchText = displayName
        completerService.suggestions = []
        isPlaceOverlayPresented = false
        geocodeErrorMessage = nil

        position = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )

        guard shouldSearchImmediately else { return }
        Task {
            await searchRestaurants(at: coordinate, keyword: shopKeyword)
        }
    }

    private func dismissKeyboard() {
        isShopKeywordFieldFocused = false
        isPlaceTextFieldFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func scheduleVisibleRegionUpdate(_ region: MKCoordinateRegion) {
        cameraRegionDebounceTask?.cancel()
        cameraRegionDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: cameraDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            visibleRegion = region
        }
    }

    private var fallbackCenterCoordinate: CLLocationCoordinate2D {
        visibleRegion?.center
            ?? locationService.currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125)
    }
}

#Preview {
    MapSearchView()
}
