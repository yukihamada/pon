# ポン App Store リジェクト対応 - 完全ガイド

**作成日時**: 2026-04-06 00:40 JST  
**ビルド番号**: 15 (CURRENT_PROJECT_VERSION)  
**バージョン**: 1.0.0

---

## 問題診断結果

### 1. IAP メタデータ不足（Guideline 2.1(b)）
**状態**: 深刻  
**原因**: App Store Connect で IAP（In-App Purchase）商品を作成したが、メタデータ（日本語・英語の名前と説明）が未設定

**現在の状態**:
- `com.enablerdao.pon.pro`: **READY_TO_SUBMIT** (メタデータなし)
- `com.enablerdao.pon.founder`: **READY_TO_SUBMIT** (メタデータなし)

### 2. Terms of Use URL（Guideline 3.1.2(c)）
**状態**: 実装済み ✅  
コード側は修正済み:
- `ProGateView.swift`: https://pon.enablerdao.com/terms リンク設定済み
- Fastlane メタデータ: eula_url.txt に設定済み

---

## 対応手順

### フェーズ 1: App Store Connect Web UI でメタデータ設定

**時間**: 約 10-15 分

#### ステップ 1: App Store Connect にログイン
```
https://appstoreconnect.apple.com
Apple ID: mail@yukihamada.jp
```

#### ステップ 2: IAP メタデータを設定

**2-1) Pon のアプリを開く**
- ダッシュボード → Apps
- "ポン - 電子契約・署名" を選択

**2-2) In-App Purchases セクションに移動**
- 左メニュー: "In-App Purchases"
- 2 つの商品が表示されるはず:
  - com.enablerdao.pon.pro
  - com.enablerdao.pon.founder

**2-3) com.enablerdao.pon.pro のメタデータを設定**

1. クリック: com.enablerdao.pon.pro
2. Localizations セクション:
   - **[+] ボタンで新しいローカライゼーション追加**
   - 言語: **日本語**
     - Name: `Proプラン`
     - Description: `無制限の契約書作成、PDF電子署名、契約管理、ステータス追跡、レポート機能を利用できます。`
   - 言語: **英語（米国）**
     - Name: `Pro Plan`
     - Description: `Unlimited contract creation, PDF e-signature, contract management, status tracking, and reporting features.`
3. 保存

**2-4) com.enablerdao.pon.founder のメタデータを設定**

1. 戻る: In-App Purchases
2. クリック: com.enablerdao.pon.founder
3. Localizations セクション:
   - **[+] ボタンで新しいローカライゼーション追加**
   - 言語: **日本語**
     - Name: `ファウンダープラン`
     - Description: `ポンの全機能に加えて、優先サポート、カスタム機能リクエストの優先対応を含みます。`
   - 言語: **英語（米国）**
     - Name: `Founder Plan`
     - Description: `All Pro features plus priority support and priority handling of custom feature requests.`
4. 保存

#### ステップ 3: Terms of Use URL が設定されているか確認
- 左メニュー: **App Information**
- セクション: **Licensing**
- **EULA**: https://pon.enablerdao.com/terms が設定されているか確認
- なければ追加

---

### フェーズ 2: TestFlight へのビルドアップロード

**時間**: 約 5-10 分  
**前提**: Web UI のメタデータ設定が完了

#### ステップ 1: ビルドをアップロード

**方法A: Transporter（推奨・簡単）**
```bash
open /Applications/Transporter.app
# （Transporter がない場合は App Store からダウンロード）
```

1. "+" ボタンをクリック
2. ファイルを選択: `/Users/yuki/workspace/pon/ios/build/export/Pon.ipa`
3. Deliver をクリック
4. ビルド処理を待機（通常 5-10 分）

**方法B: App Store Connect Web UI（代替）**
1. ダッシュボード → ポン → TestFlight → Builds
2. "+" ボタン → `/Users/yuki/workspace/pon/ios/build/export/Pon.ipa` を選択
3. Wait for processing

#### ステップ 2: ビルドが App Store Connect に表示されるのを待つ
- TestFlight → Builds: ビルド「15」が表示される
- ステータスは「Processing」→「Ready to Submit」に変化

---

### フェーズ 3: App Store 版の準備と審査提出

**時間**: 約 10-15 分

#### ステップ 1: アプリ バージョンを開く
- 左メニュー: **App Store**
- バージョン: **1.0.0** または **1.0.1** を選択
  - （新規バージョンがない場合は "+" で追加）

#### ステップ 2: 必須メタデータを入力

**What's New（リリースノート）**:
```
【バージョン 1.0.1 での改善】
- PDF電子署名機能を追加しました（PencilKitを使用）
- 契約管理機能を改善
- Pro・ファウンダープランのサブスクリプション対応
- App Store Connect IAP メタデータの設定完了
```

**Keywords（検索キーワード）**:
```
ポン, 契約, 署名, 管理, ビジネス
```

**Demo Account Required**:
```
No
```

**Review Notes（審査チーム向けメモ）**:
```
【サブスクリプション機能について】
本アプリは以下のサブスクリプション機能を提供しています：
- Proプラン（¥480/月）: 無制限の契約書作成、PDF電子署名、契約管理、ステータス追跡、レポート機能
- ファウンダープラン（¥980/月）: Pro機能全て + 優先サポート + カスタム機能リクエスト優先対応

【メタデータについて】
- アプリ内では StoreKit 2 を使用して正式にサブスクリプション商品を取得・販売しています。
- IAP メタデータは App Store Connect 管理画面で完全に設定しています。
- Terms of Use（利用規約）: https://pon.enablerdao.com/terms

【テスト方法】
本アプリはログイン不要で動作します。デモアカウントは不要です。
- 任意のセクションのPro機能をタップするとProGateViewが表示されます。
- SettingsタブからもProプランを購入できます。
- 復元ボタンで過去の購入を復元できます。
```

#### ステップ 3: ビルドを紐づける
- **Build** セクション:
  - ドロップダウン: `Pon 15` を選択（先ほどアップロードしたビルド）

#### ステップ 4: 審査に提出
1. 上部の **Submit for Review** ボタンをクリック
2. 確認画面で **Submit** をクリック
3. 審査状況は Activity セクションで確認

---

## ビルド情報

| 項目 | 値 |
|------|-----|
| **バージョン番号** | 1.0.0 |
| **ビルド番号** | 15 |
| **IPA パス** | `/Users/yuki/workspace/pon/ios/build/export/Pon.ipa` |
| **IPA サイズ** | 984 KB |
| **アーカイブパス** | `/Users/yuki/workspace/pon/ios/build/Pon.xcarchive` |
| **署名スタイル** | Automatic（Apple 提供) |
| **チーム** | 5BV85JW8US |

---

## 重要なコード実装

### ProGateView.swift（Pro ゲートView）
```swift
private var footerSection: some View {
    HStack(spacing: 16) {
        Link("利用規約", destination: URL(string: "https://pon.enablerdao.com/terms")!)
        Text("·").foregroundStyle(.tertiary)
        Link("プライバシーポリシー", destination: URL(string: "https://pon.enablerdao.com/privacy")!)
    }
    .font(.caption).foregroundStyle(.secondary)
}
```

### SubscriptionManager.swift（StoreKit 2）
```swift
static let proProductID = "com.enablerdao.pon.pro"
static let founderProductID = "com.enablerdao.pon.founder"

func fetchProduct() async {
    let products = try await Product.products(for: [Self.proProductID, Self.founderProductID])
    // ...
}
```

---

## チェックリスト

### Web UI 操作
- [ ] App Store Connect にログイン
- [ ] **IAP: com.enablerdao.pon.pro**
  - [ ] 日本語 (ja): 名前 = "Proプラン", 説明を設定
  - [ ] 英語 (en-US): 名前 = "Pro Plan", 説明を設定
- [ ] **IAP: com.enablerdao.pon.founder**
  - [ ] 日本語 (ja): 名前 = "ファウンダープラン", 説明を設定
  - [ ] 英語 (en-US): 名前 = "Founder Plan", 説明を設定
- [ ] **App Information → Licensing**: EULA = https://pon.enablerdao.com/terms

### ビルドとアップロード
- [ ] IPA (`/Users/yuki/workspace/pon/ios/build/export/Pon.ipa`) が存在
- [ ] Transporter で IPA をアップロード
- [ ] ビルド 15 が TestFlight で "Ready to Submit" に表示

### App Store 審査提出
- [ ] バージョン 1.0.0 または 1.0.1 を作成
- [ ] What's New を入力
- [ ] Keywords を入力
- [ ] Demo Account Required = No
- [ ] Review Notes を入力
- [ ] ビルド 15 を紐づけ
- [ ] **Submit for Review** をクリック

---

## トラブルシューティング

### Q: IAP メタデータを Web UI で作成できない（エラーが出る）
**A**: 以下を確認:
1. In-App Purchases セクションに商品が 2 つ表示されているか
2. 商品の State が READY_TO_SUBMIT か
3. ローカライゼーション追加時に正しい言語（ja, en-US）を選択したか

### Q: Transporter で IPA をアップロードできない
**A**: 
1. App Store から Transporter をダウンロード（最新版）
2. Apple ID が同じチーム（5BV85JW8US）に属しているか確認
3. 別の方法: App Store Connect Web UI → TestFlight → Builds から直接アップロード

### Q: ビルド 15 がアップロードされない
**A**:
1. ネットワーク接続を確認
2. IPA ファイルのサイズが 1 GB 以下か確認
3. 別の方法: Web UI から直接アップロード試行

### Q: Signing Identity エラー
**A**: ビルド時に以下を確認:
- CODE_SIGN_STYLE: Automatic
- DEVELOPMENT_TEAM: 5BV85JW8US
- Xcode → Preferences → Accounts で Apple ID がログイン済み

---

## 次のステップ

1. **即座**（今から 10 分以内）
   - [ ] Web UI でメタデータを設定
   - [ ] IPA を Transporter でアップロード

2. **ビルド処理中（5-10 分待機）**
   - ビルド 15 が TestFlight に "Processing" 中

3. **ビルド完了後（10-15 分）**
   - [ ] App Store バージョンの詳細を入力
   - [ ] ビルド 15 を紐づけ
   - [ ] Submit for Review をクリック

4. **審査期間（通常 24-48 時間）**
   - App Store Connect の Activity で状況を確認
   - リジェクトされた場合は Resolution Center のメッセージを確認

---

## 参考リンク

- [App Store Connect](https://appstoreconnect.apple.com)
- [App Store Connect API - In-App Purchases](https://developer.apple.com/documentation/appstoreconnectapi/in_app_purchases)
- [In-App Purchase Programming Guide](https://developer.apple.com/in-app-purchase)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

---

## 注記

このドキュメントは以下の問題を解決します:
1. **Guideline 2.1(b)**: IAP メタデータ不足
2. **Guideline 3.1.2(c)**: Terms of Use メタデータ不足（既に実装済み）

最後のアップロード・提出は **Web UI による手動操作** で行います。Apple による検証・署名の都合上、完全な自動化は困難です。
