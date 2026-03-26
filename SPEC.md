# GourmeSearch 簡易仕様書

## 1. アプリ概要
- ホットペッパーグルメサーチ API を使って、現在地付近の飲食店を検索する iOS アプリ。
- **MapKit中心UI** を採用:
  - メイン: 地図画面（現在地中心 + ユーザー位置表示）
  - 下部: ハーフモーダルで検索結果リスト
  - 詳細: 店舗詳細画面

## 2. 開発技術
- 言語: Swift
- UI: SwiftUI
- 地図: MapKit
- 通信: URLSession
- 位置情報: CoreLocation

## 3. HOTPEPPER_API_KEY の設定手順
1. Xcode で `GourmeSearch.xcodeproj` を開く。
2. `TARGETS > GourmeSearch > Build Settings` を開く。
3. 検索欄で `HOTPEPPER_API_KEY` を検索する。
4. `Info.plist Values` の `HOTPEPPER_API_KEY`（Debug / Release）へ API キーを入力する。
5. もし読込失敗する場合は `Info` タブの `Custom iOS Target Properties` に `HOTPEPPER_API_KEY` (String) を追加して同じ値を入れる。
5. 実行して検索機能を確認する。

## 4. 未設定時の挙動
- `HOTPEPPER_API_KEY` が未設定、または空文字の場合、アプリ内で `missingAPIKey` エラーになる。
- 表示メッセージ:  
  `APIキーが設定されていません。Build Settings の HOTPEPPER_API_KEY を設定してください。`

## 5. 画面仕様（MapKit版）

### 5.1 メイン地図画面
- 起動時に地図を表示。
- 現在地ボタンで現在地へ移動。
- 地点名入力 + 虫眼鏡ボタンでジオコーディング検索。
- 半径切替ボタン（200 / 500 / 1000 / 2000 / 3000m）。
- 検索後、店舗を地図上にピン表示。

### 5.2 ハーフモーダル検索結果
- 下部シートに検索結果一覧を表示。
- 一覧項目: 店舗名 / アクセス / サムネイル。
- 一覧から詳細画面へ遷移可能。

### 5.3 店舗詳細画面
- 表示項目: 店舗名 / 住所 / 営業時間 / 画像 / アクセス。
- 外部リンク: 店舗ページを開く / 地図で開く。

## 6. 既知の注意点
- `MapSearchView` の地図・シート統合を優先しており、旧 `SearchInputView` は補助導線として残っている。
- 半径はUIではm表示だが、API送信時は `range(1...5)` に変換している。
- APIキー管理の高度化（`xcconfig` 分離など）は対象外。
