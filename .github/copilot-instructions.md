# GourmeSearch 向け Copilot Instructions

## ビルド・テスト・Lint コマンド

- Xcodeで開く: `open GourmeSearch/GourmeSearch.xcodeproj`
- CLIでビルド:
  - `xcodebuild -project GourmeSearch/GourmeSearch.xcodeproj -scheme GourmeSearch -destination 'generic/platform=iOS Simulator' build`
- 現在の `GourmeSearch.xcodeproj` はアプリ単一ターゲットで、テストターゲットが未作成です。
  - テスト追加後の単体実行例: `xcodebuild test -project GourmeSearch/GourmeSearch.xcodeproj -scheme GourmeSearch -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GourmeSearchTests/<TestClass>/<testMethod>`
- Lint設定（SwiftLint等）は未導入です。

## 高レベルアーキテクチャ

- エントリーポイントは `GourmeSearchApp.swift`。起動時に `MapSearchView` を表示。
- 構成は `View + Service + Model` の薄いレイヤ分離。
  - `Views/`: 画面状態とUI制御（Map/UI/シート遷移）
  - `Services/`: API・位置情報
  - `Models/`: 画面表示モデルとAPI DTO
- 検索フロー（Map中心）:
  - 地点選択はオーバーレイで実施（`MKLocalSearchCompleter` サジェスト + ジオコーディング）
  - 地点を再選択する時は、オーバーレイ表示時に入力欄を自動フォーカスし既存テキストを全選択
  - 店名検索は上部バーから実行
  - 店名検索の検索ボタン押下時はキーボードを明示的に閉じる
  - 検索基準座標は「選択地点があればそれ、なければ現在地」
  - `HotpepperAPIService` がDTOを `Restaurant` 配列へ変換
  - 結果は地図ピンと下部シート `SearchResultsView` に同時反映
- 詳細表示は同一シート内の `NavigationStack` で遷移管理し、モーダル多重表示を避ける。

## このコードベース固有の重要規約

- APIキー解決は必ずフォールバック対応を維持すること:
  - `HOTPEPPER_API_KEY`
  - `INFOPLIST_KEY_HOTPEPPER_API_KEY`
  - 実装: `HotpepperAPIService.resolveAPIKey()`
- Hotpepperレスポンスは型揺れ前提で扱うこと:
  - `ResultsDTO` の lossy int decode
  - `ShopDTO.lat/lng` の lossy double decode
  - 実装: `Models/HotpepperDTO.swift`
- iOS 26対応:
  - 地点ジオコーディングは `MKGeocodingRequest`（26+）
  - それ未満は `MKLocalSearch.Request` でフォールバック
  - `placemark` ではなく `location.coordinate` を使用
- 下部シート高さは状態駆動（初期low / 検索後medium / 詳細表示時large / 詳細終了でmedium）。
- 地図ピン描画はパフォーマンス規約を維持:
  - 表示範囲内件数がしきい値超過なら**画像ピンを0件**にして赤ピンへ切替（画像ピンの残留を許容しない）
  - 画像ピン表示時も最大件数制限（現在12件）を超えないこと
  - 画像ピンは四角（角丸）表示
  - カメラ更新は `onMapCameraChange(frequency: .continuous)` で連続追従
- 画像表示は `AsyncImage` 直書きではなく `CachedRemoteImage`（`NSCache`）を優先。

## 壊れやすい箇所（変更時チェック）

- `MapSearchView` のピン表示モード切替（画像/赤ピン）の条件式を崩すと、ズームアウト時に画像ピンが残留しやすい。
- `SearchResultsView` の遷移経路を変えると、single-sheet制約警告が再発しやすい。
- 地点選択オーバーレイと店名検索バーの責務を混ぜると、検索基準地点ロジックが破綻しやすい。

## 関連ドキュメント（整合対象）

- `SPEC.md`: 仕様・セットアップ
- `.github/opilot-instructions.md`: 継続作業の文脈
- `LEARNING_NOTES.md`: 新規API/概念の学習ログ
