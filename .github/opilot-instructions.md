# opilot-instructions.md

## 目的（次エージェント向け）

このリポジトリは、Hotpepper グルメサーチ API を使う iOS（SwiftUI）アプリです。  
現在の主軸は **MapKit中心UI** です。ユーザーは「実装だけでなく理解重視」を強く希望しています。

---

## 現在の仕様（ユーザー合意済み）

- 起動直後に地図を表示（現在地中心・青い現在地マーカー）
- 上部に地点検索入力 + 虫眼鏡ボタン
- 上部右に「現在地」検索ボタン
- 右上寄りに半径切替ボタン（200/500/1000/2000/3000m）
- 検索実行で、地図ピンと下部ハーフモーダル（検索結果一覧）を同時更新
- 地点検索は「地点名文字列 -> 座標（Geocoder）」で実施
- 地点入力は 1 文字ごとにサジェスト表示

---

## 現在の実装状態（2026-03-21 更新）

### エントリーポイント

- `GourmeSearch/GourmeSearch/GourmeSearch/GourmeSearchApp.swift`
  - 起動Viewは `MapSearchView()` に切替済み

### 主要画面

- `GourmeSearch/GourmeSearch/GourmeSearch/Views/MapSearchView.swift`
  - `Map(position:)` + `UserAnnotation()` 実装済み
  - 店舗ピン表示（`Annotation`）
  - ピンUIは `AsyncImage(url: restaurant.thumbnailURL)` の円形サムネイル
  - 地点検索（入力 + 虫眼鏡）と現在地検索の両方を実装
  - 半径ボタンの循環切替（200/500/1000/2000/3000）
  - サジェストは `MKLocalSearchCompleter` で逐次表示
  - 検索結果は `restaurants` に集約し、地図と一覧へ同時反映
  - 検索後に `fitMapToRestaurants()` で表示範囲を自動調整

- `GourmeSearch/GourmeSearch/GourmeSearch/Views/SearchResultsView.swift`
  - 表示専用リスト化済み（外部配列 `restaurants` を受け取る）
  - `@Binding selectedRestaurant` を受け取り、`navigationDestination(item:)` で詳細遷移

- `GourmeSearch/GourmeSearch/GourmeSearch/Views/RestaurantDetailView.swift`
  - 店舗詳細表示（店舗名/住所/営業時間/画像 + 補助情報）

### サービス/モデル

- `Services/HotpepperAPIService.swift`
  - APIキー解決（`HOTPEPPER_API_KEY` と `INFOPLIST_KEY_HOTPEPPER_API_KEY` のフォールバック）
  - APIコール、DTOデコード、`Restaurant` への変換
  - 取得件数は高めに設定（都市部の偏り緩和目的）

- `Models/HotpepperDTO.swift`
  - Hotpepperの型揺れに耐えるデコード（数値/文字列混在など）
  - `lat/lng` は実データに合わせて `Double` 系で処理

- `Services/LocationService.swift`
  - 位置情報許可と現在地取得

---

## 直近で発生・対応した不具合

### 1) APIキー未設定エラー

- 原因: Build Settings と Info.plist 経由キー名の差異
- 対応: APIキー読み取りのフォールバック追加（上記2キー）

### 2) APIレスポンス解析失敗

- 原因: Hotpepperレスポンスの型揺れ（数値/文字列、緯度経度の型差）
- 対応: DTOを堅牢化（Lossy decode）

### 3) モーダル競合

- 現象: `Currently, only presenting a single sheet is supported.`
- 原因: 結果ハーフシート表示中に、別モーダル（詳細）を重ねた
- 最新対応:
  - `MapSearchView` の詳細表示用 `fullScreenCover` を撤去
  - 詳細は `SearchResultsView`（sheet内のNavigationStack）で `navigationDestination(item:)` に統一
  - これで「single sheet制約」の回避を狙っている

---

## 次エージェントで最優先確認すること

1. 実機/Simulatorで以下を確認
   - 検索後、地図ピンタップ -> 詳細遷移が確実に発火するか
   - `single sheet` 警告が再発しないか
   - サジェスト表示/選択後の検索が自然に動くか

2. もしピンタップ遷移が不安定なら、遷移責務を明確化
   - 方針A: 「詳細遷移は下部リストからのみ」に限定
   - 方針B: ピンタップ時は sheet 内のナビゲーションを明示的にトリガーする構成へ統一

3. `LEARNING_NOTES.md` と `SPEC.md` を最終仕様に合わせる
   - 特にモーダル競合対策の意図を明文化

---

## 実装スタイル（絶対遵守）

- 1ステップずつ小さく進める（ユーザー理解優先）
- 各ステップで必ず説明:
  - 目的
  - 実装内容
  - なぜその設計か
  - ユーザー確認ポイント
- 新しいAPI/概念は `LEARNING_NOTES.md` に追記
- 速さより理解・再現性を優先

---

## 参照ファイル

- 学習ノート: `LEARNING_NOTES.md`
- 仕様: `SPEC.md`
- セッション計画: `/Users/cmstudent/.copilot/session-state/1b623a26-999b-49d7-94d9-2a88cdf64e82/plan.md`

---

## 注意事項

- `project.pbxproj` へAPIキー直書きは避ける（ローカル設定へ）
- 作業ツリーは汚れている可能性があるため、差分確認を徹底
- `MapTestView.swift` は旧試作。現行実装は `MapSearchView.swift` を正とする
