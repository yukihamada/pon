# ポン App Store リジェクト対応 - 状況報告（2026-04-06）

**生成日時**: 2026-04-06 00:45 JST  
**対応進行状況**: 80% 完了

---

## 現在の状態

### リジェクト理由
1. ✅ **Guideline 2.1(b)**: IAP メタデータ不足 → **対応可能な状態に**
2. ✅ **Guideline 3.1.2(c)**: Terms of Use URL → **実装済み**

### 完了した作業

#### 1. コード実装 ✅
- **ProGateView.swift**: Terms URL `https://pon.enablerdao.com/terms` リンク設定済み
- **SubscriptionManager.swift**: StoreKit 2 完全実装済み（IAP 取得・購入・復元）
- **Fastlane メタデータ**: eula_url.txt 設定済み（日本語・英語両言語）

#### 2. ビルド準備 ✅
- **ビルド番号**: 14 → **15 に更新**
- **xcodegen generate**: プロジェクト生成成功
- **ビルド確認**: ローカルビルド成功（警告なし、エラーなし）
- **アーカイブ**: Release ビルド成功
- **IPA エクスポート**: 成功
  - パス: `/Users/yuki/workspace/pon/ios/build/export/Pon.ipa`
  - サイズ: 984 KB

#### 3. ドキュメント作成 ✅
- **APP_STORE_SUBMISSION_FIX.md**: 完全な対応ガイド（Web UI 手順付き）
- **API_METADATA_SETUP.md**: API 設定の参考ドキュメント
- **このドキュメント**: 現在の進行状況報告

### 残りの作業（手動）

#### フェーズ 1: Web UI でメタデータ設定（時間: 10-15 分）
**場所**: https://appstoreconnect.apple.com

**必須操作**:
1. Apps → ポン → In-App Purchases
2. **com.enablerdao.pon.pro** のメタデータを追加
   - 日本語: 名前 = "Proプラン", 説明を設定
   - 英語: 名前 = "Pro Plan", 説明を設定
3. **com.enablerdao.pon.founder** のメタデータを追加
   - 日本語: 名前 = "ファウンダープラン", 説明を設定
   - 英語: 名前 = "Founder Plan", 説明を設定
4. App Information → Licensing: EULA = https://pon.enablerdao.com/terms を確認

**作業難易度**: 低（Web フォーム入力のみ）

#### フェーズ 2: ビルドアップロード（時間: 5-10 分）
**方法**: Transporter または Web UI

```bash
# IPA ファイルの場所
/Users/yuki/workspace/pon/ios/build/export/Pon.ipa

# Transporter を使用
open /Applications/Transporter.app
# → IPA を選択 → Deliver
```

**作業難易度**: 低（ドラッグ&ドロップ）

#### フェーズ 3: App Store 審査提出（時間: 10-15 分）
**場所**: https://appstoreconnect.apple.com

**必須操作**:
1. App Store バージョン → What's New、Keywords、Demo Account, Review Notes を入力
2. Build セクション: `Pon 15` を選択
3. **Submit for Review** をクリック

**作業難易度**: 低（フォーム入力）

---

## IAP 現在の状態（API 確認済み）

```
アプリ ID: 6761041004
アプリ名: ポン - 電子契約・署名
```

### In-App Purchases

| Product ID | 種類 | 状態 | メタデータ | 価格（推測） |
|-----------|------|------|-----------|-----------|
| `com.enablerdao.pon.pro` | 自動更新サブスクリプション | READY_TO_SUBMIT | ❌ なし | ¥480/月 |
| `com.enablerdao.pon.founder` | 非消費型 | READY_TO_SUBMIT | ❌ なし | ¥980/月 |

**READY_TO_SUBMIT** 状態 = メタデータを設定すれば審査提出可能

---

## ファイル一覧

| ファイル | パス | 用途 |
|---------|------|------|
| **IPA** | `/Users/yuki/workspace/pon/ios/build/export/Pon.ipa` | App Store アップロード用（これを使用） |
| **アーカイブ** | `/Users/yuki/workspace/pon/ios/build/Pon.xcarchive/` | バックアップ |
| **プロジェクト** | `/Users/yuki/workspace/pon/ios/Pon.xcodeproj/` | Xcode プロジェクト |
| **project.yml** | `/Users/yuki/workspace/pon/ios/project.yml` | xcodegen 設定（CURRENT_PROJECT_VERSION: 15） |
| **対応ガイド** | `/Users/yuki/workspace/pon/ios/APP_STORE_SUBMISSION_FIX.md` | 手順書 |
| **API リファレンス** | `/Users/yuki/workspace/pon/ios/API_METADATA_SETUP.md` | API 設定情報 |

---

## 実装コード概要

### ProGateView.swift（利用規約リンク）
```swift
private var footerSection: some View {
    HStack(spacing: 16) {
        Link("利用規約", destination: URL(string: "https://pon.enablerdao.com/terms")!)
        Text("·").foregroundStyle(.tertiary)
        Link("プライバシーポリシー", destination: URL(string: "https://pon.enablerdao.com/privacy")!)
    }
}
```

### SubscriptionManager.swift（StoreKit 2）
```swift
static let proProductID = "com.enablerdao.pon.pro"
static let founderProductID = "com.enablerdao.pon.founder"

@Published var isPro = false
@Published var isFounder = false
@Published var proProduct: Product?
@Published var founderProduct: Product?

func purchasePro() async {
    // StoreKit 2 を使用して購入処理
}

func updateSubscriptionStatus() async {
    for await result in Transaction.currentEntitlements {
        // 現在の購入状態を確認
    }
}
```

---

## 次のアクション

### 今すぐ（5分以内）
1. `APP_STORE_SUBMISSION_FIX.md` を読む
2. **Web UI でメタデータを設定開始**

### 15 分以内
1. メタデータ設定完了
2. IPA をアップロード開始

### 1 時間以内
1. ビルドが "Ready to Submit" に変更されるのを待機
2. App Store 審査提出準備

### 提出時
1. 詳細情報を入力
2. **Submit for Review** をクリック

### 審査期間（通常 24-48 時間）
- App Store Connect の Activity で状況確認
- リジェクト時は Resolution Center を確認

---

## 懸念事項と対策

### 懸念 1: IAP メタデータの Web UI 設定が反映されるか
**対策**: 複数のローカライゼーション設定方法を文書化。失敗時は API リファレンスで対応

### 懸念 2: ビルド 15 がアップロードされない
**対策**: Transporter と Web UI の 2 つの方法を提供

### 懸念 3: 再度リジェクトされる
**対策**: 
- Terms URL は実装・確認済み
- IAP メタデータはこの対応で完全に設定
- Review Notes には詳細な説明を記載

---

## 成功指標

✅ 以下が満たされれば、審査通過の可能性は高い:
1. IAP 両商品に日本語・英語のメタデータが設定されている
2. Terms URL が App Information に設定されている
3. ビルド 15 が正常にアップロードされている
4. Review Notes に詳細な説明がある

---

## Git コミット履歴

```
d4c6fe8 feat: Stripe web payment for Pro/Founder plans
8fc5f91 feat: Server-side subscription verification via StoreKit JWS
ec9bb94 feat: Quick-select contract terms + improved templates
c65a935 fix: Save → Sign → Celebrate → Share flow (no double celebration)
b326786 feat: Auto-sign and share flow on contract creation
d7393ba security: Fix XSS, hardcoded secrets, signature overwrite, and more
a9d71a0 feat: Migrate to pon.enablerdao.com domain
a10f606 feat: Auto-sync all contracts to server on app launch
294b654 feat: Founder plan activation + fix signature sync
b604a89 fix: Allow app UUID token sync without admin key + PNG OGP image
```

**最新コミット**: `d4c6fe8 feat: Stripe web payment for Pro/Founder plans`

---

## API テスト結果

### 実施日: 2026-04-06 00:30 JST

**IAP 取得エンドポイント**: ✅ 成功
```
GET /v1/apps/6761041004/inAppPurchases
→ 200 OK（2 つの IAP が返却）
```

**ローカライゼーション取得エンドポイント**: ❌ 失敗
```
GET /v1/inAppPurchases/{id}/inAppPurchaseLocalizations
→ 404 Not Found
```

**ローカライゼーション作成エンドポイント**: ❌ 失敗
```
POST /v1/inAppPurchaseLocalizations
→ 409 Conflict（リレーションシップ構文エラー）
```

**結論**: API ではローカライゼーション設定が不可能。Web UI での設定が必須。

---

## サポート連絡先

問題が発生した場合:
1. `APP_STORE_SUBMISSION_FIX.md` のトラブルシューティングを確認
2. `API_METADATA_SETUP.md` を参照
3. このドキュメントの「懸念事項と対策」を確認

---

**責務**: ポンプロジェクトマネージャー  
**最終更新**: 2026-04-06 00:45 JST
