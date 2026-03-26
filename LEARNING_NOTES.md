# LEARNING NOTES

このファイルは、実装中に出てきた「新しいメソッド/型/属性」を理解するためのメモです。  
以後、Issueごとに新しく出た要素を追記します。

## これまでに出てきた新要素（#7, #8）

### `CLLocationManager`
- 何か: iOSの位置情報取得を担当する標準クラス（CoreLocation）。
- 何に使うか: 現在地取得、継続位置更新、権限状態の確認。
- 今回の使い方: `LocationService` 内で1インスタンスを保持して利用。

### `CLLocationManagerDelegate`
- 何か: `CLLocationManager` の結果通知を受け取るためのdelegateプロトコル。
- 何に使うか: 「権限変更」「位置取得成功」「位置取得失敗」を受ける。
- 一般的な活用: `locationManagerDidChangeAuthorization`, `didUpdateLocations`, `didFailWithError` を実装する。

### `ObservableObject`
- 何か: SwiftUIで「状態を外部へ通知するオブジェクト」を表すプロトコル。
- 何に使うか: Service側の状態変更をViewに伝える。
- 一般的な活用: Viewで `@StateObject` / `@ObservedObject` と組み合わせる。

### `@Published`
- 何か: `ObservableObject` 内の「変更通知するプロパティ」用属性。
- 何に使うか: 値が変わると、購読しているViewが再描画される。
- 今回の対象: `authorizationStatus`, `errorMessage`（今後 `currentLocation` も追加予定）。

### `CLAuthorizationStatus`
- 何か: 位置情報権限の状態を表すenum。
- 主な状態:
  - `.notDetermined`（まだ聞いていない）
  - `.authorizedWhenInUse`（使用中のみ許可）
  - `.authorizedAlways`（常時許可）
  - `.denied`（拒否）
  - `.restricted`（制限）
- 今回の使い方: `requestCurrentLocation()` の `switch` 分岐。

### `requestWhenInUseAuthorization()`
- 何か: 「アプリ使用中の位置情報許可」をOSにリクエストするメソッド。
- いつ使うか: 権限状態が `.notDetermined` のとき。

### `requestLocation()`
- 何か: 現在地を1回だけ取得するメソッド。
- いつ使うか: すでに権限が許可されているとき。
- 補足: 結果はdelegate経由で返る（同期で値が返るわけではない）。

### `@unknown default`
- 何か: `switch` で将来enumケースが増えた時に備える分岐。
- 何に使うか: 予期しないケースでも安全に処理する。

### `locationManagerDidChangeAuthorization(_:)`
- 何か: 位置情報権限の状態が変わった時に呼ばれるdelegateメソッド。
- 何に使うか: 「初回許可された直後」に続けて位置取得を開始する。
- 今回の使い方: `authorizationStatus` を更新し、許可状態なら `requestLocation()` を呼ぶ。
- 一般的な活用: 権限変更をトリガーにUI更新（許可済み表示/警告表示）や次アクション実行を行う。

### `locationManager(_:didUpdateLocations:)`
- 何か: 位置情報の取得に成功した時に呼ばれるdelegateメソッド。
- 何に使うか: 取得結果（座標）をアプリの状態に反映する。
- 今回の使い方: `locations.last` を `currentLocation` に保存し、`errorMessage` をクリア。
- 一般的な活用: 現在地表示更新、近隣検索のトリガー、地図中心座標の更新。

### `CLLocation`
- 何か: 1つの位置情報（緯度・経度・精度・時刻など）を表す型。
- 何に使うか: `coordinate.latitude` / `coordinate.longitude` で座標を参照する。
- 今回の使い方: `currentLocation` の型として保持する。

### `locationManager(_:didFailWithError:)`
- 何か: 位置情報取得が失敗した時に呼ばれるdelegateメソッド。
- 何に使うか: 失敗理由を状態に保存し、画面側でユーザーへ表示する。
- 今回の使い方: `error.localizedDescription` を `errorMessage` に代入。
- 一般的な活用: 取得リトライ導線の表示、設定アプリ誘導、ログ出力。

## 追加（#12）

### `Bundle.main.object(forInfoDictionaryKey:)`
- 何か: アプリの `Info.plist` に入っている値を取得するメソッド。
- 何に使うか: APIキーや表示名など、ビルド設定から注入された値の読込。
- 今回の使い方: `HOTPEPPER_API_KEY` を文字列として取得。
- 一般的な活用: 環境ごとの設定値（APIキー、Base URL、フラグ）の受け取り。

### `LocalizedError`
- 何か: ユーザー表示向けのエラー文言（`errorDescription`）を持てるプロトコル。
- 何に使うか: `catch` 後にわかりやすいメッセージを表示する。
- 今回の使い方: `HotpepperAPIError.missingAPIKey` に説明文を付与。

## 追加（#13）

### `URLComponents`
- 何か: URLの各要素（scheme/host/path/query）を安全に組み立てる型。
- 何に使うか: 文字列連結せず、クエリパラメータを安全に付与する。
- 今回の使い方: `lat/lng/range/start/count/keyword` を `queryItems` に設定。
- 一般的な活用: APIリクエストURL生成、URLエンコード自動化、条件付きクエリ追加。

### `URLQueryItem`
- 何か: URLのクエリ1項目（name=value）を表す型。
- 何に使うか: クエリ文字列を安全に作る。
- 今回の使い方: `key=format=...` などを1件ずつ追加。

### `trimmingCharacters(in:)`
- 何か: 文字列の前後空白や改行を取り除くメソッド。
- 何に使うか: 入力が空白だけの場合を「空」として判定する。
- 今回の使い方: `keyword` が空白のみならクエリ追加しない。

## 追加（#14）

### `URLSession.shared.data(from:)`
- 何か: 指定URLへ非同期リクエストを送り、`(Data, URLResponse)` を返すメソッド。
- 何に使うか: APIから生データを取得する。
- 今回の使い方: 組み立て済みURLで検索APIを呼び、レスポンスDataを受け取る。
- 一般的な活用: JSON API取得、画像取得、ダウンロード処理。

### `HTTPURLResponse`
- 何か: `URLResponse` のうち、HTTPのステータスコード等を持つ型。
- 何に使うか: `statusCode` を見て成功/失敗を判定する。
- 今回の使い方: 2xx以外なら `badStatusCode` エラーを投げる。

### `async throws`
- 何か: 「非同期」かつ「失敗時にエラーを投げる」関数宣言。
- 何に使うか: ネットワークなど時間がかかり、失敗可能な処理を安全に扱う。
- 今回の使い方: `fetchRawSearchData(query:start:)` を `async throws` で定義。

## 追加（#15）

### `JSONDecoder().decode(_:from:)`
- 何か: JSONの `Data` を `Decodable` 型へ変換する標準API。
- 何に使うか: APIレスポンスをSwift型で安全に扱う。
- 今回の使い方: `HotpepperAPIResponse` へデコードし、失敗時は `decodeError` を返す。

### `map`
- 何か: 配列の各要素を別の型に変換して新しい配列を作る関数。
- 何に使うか: DTO配列を表示用モデル配列に変換する。
- 今回の使い方: `decoded.results.shops.map { ...Restaurant... }` で変換。

### `nil` 合体演算子 `??`
- 何か: 左辺が `nil` のとき右辺のデフォルト値を使う演算子。
- 何に使うか: API値欠損時の表示文言フォールバック。
- 今回の使い方: `shop.mobileAccess ?? "アクセス情報なし"` など。

## 追加（#16）

### `@StateObject`
- 何か: Viewが所有する参照型オブジェクトを、再描画でも保持するための属性。
- 何に使うか: `ObservableObject` のライフサイクル管理。
- 今回の使い方: `LocationService` を `SearchInputView` で保持。

### `NavigationStack` + `navigationDestination(for:)`
- 何か: 型安全な画面遷移を行うSwiftUIのナビゲーション機構。
- 何に使うか: `NavigationLink(value:)` で値を渡して遷移する。
- 今回の使い方: `SearchQuery` を値として検索結果画面へ渡す。

### `Form` / `Section`
- 何か: 入力フォーム向けのUIコンテナ。
- 何に使うか: 設定項目や入力項目をグループ化して見やすくする。
- 今回の使い方: 「現在地」「検索条件」「実行」の3セクションでUIを整理。

## 追加（#17）

### `.task { ... }`
- 何か: View表示タイミングで非同期処理を実行するSwiftUI modifier。
- 何に使うか: 初回表示時のデータ読込。
- 今回の使い方: 検索結果画面表示時に `loadFirstPage()` を実行。

### `defer`
- 何か: 関数を抜ける直前に必ず実行される処理を定義する構文。
- 何に使うか: 成功/失敗どちらでも後処理を確実に行う。
- 今回の使い方: `isLoading = false` を必ず実行。

### `guard !isLoading else { return }`
- 何か: 早期returnで重複実行を防ぐガード条件。
- 何に使うか: 二重タップや再描画による多重リクエスト防止。
- 今回の使い方: 初回読込中に再読込処理へ入らないよう制御。

## 追加（#18）

### ページング用 `nextStart`
- 何か: 次に取得する開始位置（APIの `start` パラメータ）。
- 何に使うか: 2ページ目以降を明示的に取得する。
- 今回の使い方: `SearchPage.nextStart` を `@State` で保持し、`nil` なら最終ページと判定。

### `append(contentsOf:)`
- 何か: 配列へ複数要素をまとめて追加するメソッド。
- 何に使うか: 次ページの結果を既存一覧に連結する。
- 今回の使い方: `restaurants.append(contentsOf: page.restaurants)`。

## 追加（#19）

### `AsyncImage`
- 何か: URLから非同期で画像を読み込んで表示するSwiftUI View。
- 何に使うか: サムネイルや外部画像の簡易表示。
- 今回の使い方: `restaurant.thumbnailURL` を一覧セルで表示し、placeholderも設定。

### `lineLimit(_:)`
- 何か: テキストの表示行数上限を指定するmodifier。
- 何に使うか: セル高さの暴走防止、一覧の見た目安定。
- 今回の使い方: 店舗名・アクセスを最大2行に制限。

## 追加（#20）

### `NavigationLink { ... } label: { ... }`
- 何か: 遷移先Viewを直接指定するナビゲーションリンク。
- 何に使うか: 一覧セルタップで詳細画面へ遷移する。
- 今回の使い方: `RestaurantRow` をラベルにし、遷移先を `RestaurantDetailView` に設定。

### `ScrollView`
- 何か: 画面全体を縦/横スクロール可能にするコンテナ。
- 何に使うか: 詳細情報が長くても表示できるようにする。
- 今回の使い方: 詳細画面の画像＋テキスト全体を縦スクロール化。

## 追加（#21）

### `Link`
- 何か: タップで外部URLを開くSwiftUIコンポーネント。
- 何に使うか: Webページや地図アプリへの遷移。
- 今回の使い方: 店舗ページURL、Apple Maps URLを開くリンクとして使用。

### `addingPercentEncoding(withAllowedCharacters:)`
- 何か: URLとして安全に扱えるよう文字列をエンコードするメソッド。
- 何に使うか: 日本語住所や空白を含む文字列をURLクエリへ載せる。
- 今回の使い方: 住所文字列を `maps.apple.com/?q=` のクエリ値に変換。

## 実装ルール（このメモの運用）

各Issueで「新しく使った要素」が出たら、以下を追記する。

- 要素名
- 何か（定義）
- 今回どう使ったか
- 一般的な活用

## 学習コメント運用テンプレ（Issue完了時）

毎Issueの完了時に、GitHub Issueコメントへ必ず以下を記録する。

- 目的:
- 実装:
- なぜ:
- 確認課題:

## 追加（APIキー読込改善）

### `for keyName in candidateKeys`
- 何か: 候補キーを順番に試すフォールバック処理。
- 何に使うか: 設定名の揺れ（`HOTPEPPER_API_KEY` / `INFOPLIST_KEY_HOTPEPPER_API_KEY`）に耐える。
- 今回の使い方: どちらかに値が入っていればAPIキーとして採用。

## 追加（デコード不一致修正）

### APIの「型揺れ」
- 何か: 同じキーでもレスポンスによって `Int` / `String` が混在する現象。
- 今回の実例: `results_available` と `results_start` は `Int`、`results_returned` は `String` で返るケースがあった。
- 対応方針: `decodeLossyInt` で「Int優先、だめならString→Int変換」を行う。

### `init(from:)` を使うカスタムデコード
- 何か: `Decodable` のデフォルト変換では足りない時に自前でデコード手順を書く方法。
- 何に使うか: 仕様どおりでないレスポンスにも耐える。
- 今回の使い方: `ResultsDTO` で3つの数値フィールドをロバストに読み取る。

## 追加（MapKit再設計: 土台）

### `Map(position:)`
- 何か: SwiftUI のMapKit表示コンポーネント。
- 何に使うか: 地図表示、カメラ位置制御、アノテーション描画。
- 今回の使い方: `MapSearchView` のメイン背景として表示。

### `MapCameraPosition.userLocation(fallback:)`
- 何か: ユーザー現在地を中心とするカメラ位置指定。
- 何に使うか: 起動時に現在地中心で地図を表示する。
- 今回の使い方: `@State private var position` の初期値として設定。

## 追加（MapKit再設計: 上部検索UI）

### `CLGeocoder`
- 何か: 住所・地点名を座標へ変換（ジオコーディング）するクラス。
- 何に使うか: 地点名検索欄から地図中心座標を決定する。
- 今回の使い方: `geocodeAddressString` で地点名を検索し、先頭結果を地図中心へ反映。

### `MapCameraPosition.region(...)`
- 何か: 指定した `MKCoordinateRegion` へ地図カメラを移動する指定。
- 何に使うか: 検索地点にズームして移動する。
- 今回の使い方: 地点名検索成功時に `latitudeDelta/longitudeDelta = 0.02` で移動。

## 追加（MapKit再設計: 半径切替）

### `%`（剰余演算子）で循環インデックス
- 何か: 配列の末尾まで行ったら先頭に戻すための計算。
- 何に使うか: ボタン1つで選択肢をループさせるUI。
- 今回の使い方: `selectedRadiusIndex = (selectedRadiusIndex + 1) % radiusMetersOptions.count`

### `Capsule()`
- 何か: カプセル型の図形（丸いピル型背景）。
- 何に使うか: ボタンラベルを視認しやすくする。
- 今回の使い方: 半径ボタンの背景シェイプとして利用。

## 追加（MapKit再設計: 検索実行統合）

### `Task { await ... }`
- 何か: 同期コンテキスト（ボタン/クロージャ）から非同期関数を起動する方法。
- 何に使うか: `async` 関数をUIイベントから呼ぶ。
- 今回の使い方: ジオコーディング完了後と現在地ボタン押下後に、API検索を非同期で実行。

### `CLLocationCoordinate2D`
- 何か: 緯度・経度を保持する座標型。
- 何に使うか: 地図移動、検索座標の受け渡し。
- 今回の使い方: `searchRestaurants(at:)` に現在地/地点検索の両方から同じ型で座標を渡す。

## 追加（MapKit再設計: 地図ピン + ハーフモーダル連携）

### `Marker`
- 何か: SwiftUI Map 上に地点ピンを描画する要素。
- 何に使うか: 検索結果店舗の位置を地図上に可視化する。
- 今回の使い方: `restaurants` を `ForEach` し、緯度経度がある店舗だけ `Marker` 表示。

### `.sheet` + `.presentationDetents`
- 何か: 下から出るモーダル（シート）と高さ段階指定。
- 何に使うか: マップを隠しすぎないハーフモーダルUIを作る。
- 今回の使い方: `SearchResultsView(restaurants:)` を常時表示に近い形で下部表示。

## 追加（検索ボタン無反応の修正）

### `withCheckedThrowingContinuation`
- 何か: コールバックAPIを `async throws` に橋渡しする仕組み。
- 何に使うか: `CLGeocoder` の完了ハンドラ型を、`await` で扱える形に変換する。
- 今回の使い方: `geocodeAddressString` を `geocodeCoordinate(for:) async throws` に変換し、検索フローを同期的に読める形へ統一。

## 追加（API解析失敗の再修正）

### `lat/lng` の型揺れ（String想定→実際はDouble）
- 何か: Hotpepper の `lat`, `lng` は実レスポンスで `float`（Double）として返るケースがある。
- 何に使うか: DTO側で型不一致を起こさないようにする。
- 今回の使い方: `ShopDTO.lat/lng` を `Double?` に変更し、`decodeLossyDoubleIfPresent` で String/Double 両対応にした。

## 追加（ユーザー要望の改善）

### `Annotation` + カスタムButton
- 何か: Map上の任意Viewアノテーションを配置する機能。
- 何に使うか: ピンをタップしてアプリ内アクション（詳細画面表示）を実行する。
- 今回の使い方: `selectedRestaurant` にセットし、`.sheet(item:)` で詳細画面を開く。

### `MKLocalSearchCompleter`
- 何か: 入力途中テキストから地点候補をリアルタイム取得するAPI。
- 何に使うか: 一文字ずつ入力時のサジェスト表示。
- 今回の使い方: `TextField` の `onChange` で `queryFragment` を更新し、候補リストをオーバーレイ表示。

### 地図の偏り緩和（`fitMapToRestaurants`）
- 何か: 取得した全店舗座標の最小/最大から表示範囲を再計算する処理。
- 何に使うか: 都市部でピンが中心に密集した時に、全体を見える範囲へ自動調整する。
- 今回の使い方: 検索後に `position = .region(...)` を更新して可視範囲を拡張。

### `fullScreenCover(item:)`
- 何か: 既存シートと衝突しにくい全画面モーダル表示。
- 何に使うか: 「sheetをすでに出している状態」で詳細を重ねる時の競合回避。
- 今回の使い方: 地図ピンタップ時の詳細画面を `sheet` ではなく `fullScreenCover` で表示。

### `AsyncImage` をアノテーション表示に利用
- 何か: マップピンを記号ではなく店舗サムネイルで表現する方法。
- 何に使うか: どの店舗か視覚的にわかりやすくする。
- 今回の使い方: 円形サムネイル（白枠付き）をピン代わりに表示。

---

必要なら次回から、各要素に「1行コード例」も追加していきます。
