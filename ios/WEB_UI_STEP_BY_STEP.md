# ポン IAP リジェクト修正 — Web UI ステップバイステップガイド

## ウィンドウ 1: App Store Connect ログイン

### URL
```
https://appstoreconnect.apple.com
```

### ログイン
- Apple ID: `mail@yukihamada.jp`
- パスワード: [Keychain から読み込み]
- 2 要素認証: 確認コードを入力

---

## ウィンドウ 2: アプリ選択

### ナビゲーション
```
左メニュー → Apps
```

### アプリ選択
```
「ポン - 電子契約・署名」をクリック
```

---

## ステップ 1: Pro プラン IAP 作成

### パス
```
ポン詳細 → 左メニュー「In-App Purchases」
```

### 画面
```
現在のIAP一覧:
□ com.enablerdao.pon.founder (Pon Founder Plan) ✅ READY_TO_SUBMIT

操作: [+] Add ボタン（右上）をクリック
```

### IAP タイプ選択
```
「Non-Consumable」を選択
（以下の理由で Non-Consumable）
- 月額サブスクリプション
- 複数プランの中から選択可能
```

### フォーム入力
```
✍️ Product ID:              com.enablerdao.pon.pro
✍️ Reference Name:           Pon Pro Plan
✍️ Renewable Subscription:   YES（チェック）
✍️ Subscription Duration:    Monthly
✍️ Price:                    ¥480
```

### 入力例スクリーンショット
```
┌────────────────────────────────────────┐
│ Create In-App Purchase                 │
├────────────────────────────────────────┤
│ Type: ○ Consumable                     │
│      ◉ Non-Consumable                  │
│      ○ Auto-Renewable Subscription     │
│                                        │
│ Product ID:                            │
│ ┌──────────────────────────────────┐  │
│ │com.enablerdao.pon.pro____________│  │
│ └──────────────────────────────────┘  │
│                                        │
│ Reference Name:                        │
│ ┌──────────────────────────────────┐  │
│ │Pon Pro Plan____________________|  │
│ └──────────────────────────────────┘  │
│                                        │
│ [Save]  [Cancel]                       │
└────────────────────────────────────────┘
```

### 保存
```
[Save] ボタンをクリック
```

### 確認
```
✅ Pro プラン作成完了
ID: com.enablerdao.pon.pro
状態: READY_TO_SUBMIT
```

---

## ステップ 2: Pro プラン ローカライゼーション追加

### パス
```
com.enablerdao.pon.pro をクリック → 詳細画面を開く
```

### Localizations タブ
```
画面上部のタブ: [Localizations] をクリック
```

### 現在のローカライゼーション
```
現在: （なし）

操作: [+ Add Localization] ボタン
```

### 日本語追加

#### フォーム
```
✍️ Locale:       Japanese (ja)
✍️ Name:         Proプラン
✍️ Description:  無制限の契約書作成、PDF電子署名、契約管理、
                 ステータス追跡、レポート機能を利用できます。
```

#### 保存
```
[Save] ボタン
```

### 英語追加（同じ画面で続ける）

#### フォーム
```
✍️ Locale:       English (en-US)
✍️ Name:         Pro Plan
✍️ Description:  Unlimited contract creation, PDF e-signature,
                 contract management, status tracking, and reporting
                 features.
```

#### 保存
```
[Save] ボタン
```

### 確認
```
✅ ローカライゼーション完了
   - ja: Proプラン
   - en-US: Pro Plan
```

---

## ステップ 3: Pro プラン スクリーンショット追加

### パス
```
com.enablerdao.pon.pro 詳細 → App Store Review Screenshot セクション
```

### 操作
```
[+ Add Screenshot] ボタンをクリック
```

### ファイル選択
```
ファイルピッカーで以下を選択:
/Users/yuki/workspace/pon/ios/iap_screenshot.png
```

### アップロード
```
[Upload] または [Save] をクリック
ファイルサイズ: 131 KB
```

### 確認
```
✅ スクリーンショット追加完了
   ファイル: iap_screenshot.png
```

---

## ステップ 4: Pro プラン 価格設定

### パス
```
com.enablerdao.pon.pro 詳細 → Pricing and Availability
```

### 価格入力
```
Base Territory: (最初に選択)

日本（Japanese）:
✍️ Price Tier:  ¥480/month
              または
✍️ Manual Price: ¥480.00
```

### 保存
```
[Save] ボタン
```

### 確認
```
✅ 価格設定完了
   Pro プラン: ¥480/month
```

---

## ステップ 5: Pro プラン 審査提出

### パス
```
com.enablerdao.pon.pro 詳細 → 上部メニュー
```

### 操作
```
[Submit for Review] ボタン（または 青いボタン）をクリック
```

### 確認ダイアログ
```
メッセージ: 「Are you sure you want to submit this in-app purchase 
for review?」

操作: [Submit] ボタンをクリック
```

### 確認
```
✅ Pro プラン 審査提出完了
   状態: READY_TO_SUBMIT → WAITING_FOR_REVIEW
   
   注: 数分から数時間で「IN_REVIEW」に変わります
```

---

## ステップ 6: 既存バージョン 1.0 を削除

### パス
```
ポン詳細 → 左メニュー「App Store」
```

### 現在のバージョン一覧
```
Version 1.0 - REJECTED ← これを削除する
```

### 操作
```
Version 1.0 をクリック → [⋯] More ボタン → [Delete] を選択
```

### 確認ダイアログ
```
メッセージ: 「This action cannot be undone. Are you sure you want 
to delete this version?」

操作: [Delete] ボタンをクリック
```

### 確認
```
✅ 既存バージョン削除完了
   Version 1.0 (REJECTED) は一覧から消える
```

---

## ステップ 7: 新規 App Store Version 1.0.1 作成

### パス
```
ポン詳細 → 左メニュー「App Store」
```

### 操作
```
[+ Add Version] または [Create Version] ボタンをクリック
```

### フォーム入力
```
Platform:       iOS
Release Type:   Manual Release
Version Number: 1.0.1
```

### 次へ
```
[Create] ボタン
```

### 確認
```
✅ Version 1.0.1 作成完了
   バージョン詳細画面が開く
```

---

## ステップ 8: Version 1.0.1 メタデータ設定

### General Information

#### What's New in This Version
```
【バージョン 1.0.1 での改善】
- Pro・ファウンダープランのサブスクリプション対応を完了
- IAP メタデータの設定完了
- PDF電子署名機能を搭載
- 契約管理機能を改善
```

#### Keywords
```
ポン, 契約, 署名, 管理, ビジネス, 電子契約, PDF
```

#### Category
```
Business （または Productivity）
```

#### Privacy Policy URL
```
https://pon.enablerdao.com/privacy
```

#### Terms of Use URL
```
https://pon.enablerdao.com/terms
```

#### Demo Account Required
```
○ YES
◉ NO （チェック）
```

### Pricing

#### Price
```
ドロップダウン: 「Free」（デフォルト）
```

---

## ステップ 9: Version 1.0.1 ビルド選択

### パス
```
Version 1.0.1 詳細 → Build セクション
```

### 操作
```
[+ Select] ボタン
```

### ビルド一覧
```
Build 16  ← これを選択
Build 15
Build 14
...
```

### 確認
```
✅ Build 16 選択完了
   Version 1.0.1 にバインド
```

---

## ステップ 10: Version 1.0.1 審査用レビューノート入力

### パス
```
Version 1.0.1 詳細 → Review Notes セクション
```

### テキスト入力
```
【サブスクリプション機能について】
本アプリは以下のサブスクリプション機能を提供しています：
- Proプラン（¥480/月）: 無制限の契約書作成、PDF電子署名、契約管理、ステータス追跡、レポート機能
- ファウンダープラン（¥980/月）: Pro機能全て + 優先サポート + カスタム機能リクエスト優先対応

【メタデータについて】
- アプリ内では StoreKit 2 を使用して正式にサブスクリプション商品を取得・販売しています
- IAP メタデータ（名前、説明、スクリーンショット）は完全に設定しています
- 両プランのローカライゼーション（日本語・英語）も完備

【デモアカウントについて】
本アプリはログイン不要で動作します。デモアカウントは不要です：
- 任意のセクションのPro機能をタップするとProGateViewが表示されます
- SettingsタブからもProプランを購入できます
- 復元ボタンで過去の購入を復元できます

【テスト方法】
1. アプリ起動（ログイン不要）
2. 任意のセクション（例：「+新規作成」）をタップ
3. Pro 機能メッセージが表示される
4. 「購入」ボタンで StoreKit 2 のサブスクリプション購入画面が開く
5. サンドボックステストで検証可能
```

---

## ステップ 11: 保存

### 操作
```
ページ下部の [Save] ボタンをクリック
```

### 確認
```
✅ メタデータ保存完了
```

---

## ステップ 12: App Store 審査提出

### パス
```
Version 1.0.1 詳細 → 右上
```

### 操作
```
[Submit for Review] ボタン（青いボタン）をクリック
```

### 最終確認ダイアログ
```
チェックリスト:
☑ All required fields are filled
☑ Build is selected
☑ IAP is configured

メッセージ: 「Are you ready to submit version 1.0.1 for review?」

操作: [Submit] ボタンをクリック
```

### 完了
```
✅ Version 1.0.1 審査提出完了！

次のステップ:
1. App Store が Version 1.0.1 を処理中（数分）
2. Status → 「In Review」に変わる
3. 審査チーム確認（24-48 時間）
4. Approved または Rejected
```

---

## ステップ 13: 審査進捗確認

### パス
```
ポン詳細 → 左メニュー「Activity」
```

### 監視項目
```
Version 1.0.1 のステータス:

⏳ In Review      → 審査中、待機
✅ Approved      → 承認！リリース準備
🚫 Rejected      → Resolution Center でコメント確認

予想完了時刻: 2026-04-09 14:00 JST 前後（24-48 時間後）
```

---

## トラブルシューティング

### Q: Pro プラン作成時にエラーが出た

**A**: 以下を確認

1. Product ID に typo がないか確認: `com.enablerdao.pon.pro`
2. 既に同じ ID が存在していないか確認
3. ネットワーク接続を確認
4. ブラウザキャッシュをクリア → 再度アクセス

### Q: ローカライゼーション追加後に反映されない

**A**: App Store は キャッシュされることがあります

1. ブラウザを再読み込み（Cmd+R）
2. 5-10 分待機
3. 別のブラウザでアクセス試行

### Q: ビルド 16 が表示されない

**A**: ビルド処理がまだ完了していない可能性

1. App Store Connect で TestFlight → Builds を確認
2. Build 16 のステータスが「Ready for Testing」以上か確認
3. 数分待ってから再確認

### Q: バージョン 1.0.1 の審査に落ちた

**A**: Resolution Center でコメント確認

1. Activity → 最新のレジェクトメッセージをクリック
2. Resolution Center で Apple からのコメント確認
3. 指摘内容に対応（IAP 追加・メタデータ修正など）
4. 新バージョン 1.0.2 で再提出

---

## 所要時間の見積もり

| ステップ | 時間 | 備考 |
|---------|------|------|
| Pro プラン作成 | 5 分 | Web UI 入力 |
| ローカライゼーション | 3 分 | ja, en-US 設定 |
| スクリーンショット | 2 分 | ファイルアップロード |
| 価格設定 | 2 分 | ¥480/month |
| Pro プラン審査提出 | 1 分 | ボタンクリック |
| 既存バージョン削除 | 1 分 | 確認と削除 |
| 新バージョン作成 | 2 分 | Version 1.0.1 |
| メタデータ設定 | 10 分 | Review Notes 等 |
| 最終審査提出 | 1 分 | ボタンクリック |
| **合計** | **27 分** | 通常の流れ |

---

**予想実施時刻**: 2026-04-07 14:00 JST 開始 → 14:30 完了  
**審査完了予想**: 2026-04-09 14:00 JST 前後
