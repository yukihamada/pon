# ポン App Store 再提出 - 最終チェックリスト

**準備完了日**: 2026-04-06  
**ビルド**: 15  
**IPA**: `/Users/yuki/workspace/pon/ios/build/export/Pon.ipa` (984 KB)

---

## 即座に実行するもの（所要時間: 30-40 分）

### ステップ 1: Web UI でメタデータを設定（10-15 分）

**アクセス**: https://appstoreconnect.apple.com

**操作**:
```
ダッシュボード
  → Apps
    → "ポン - 電子契約・署名" をクリック
      → In-App Purchases（左メニュー）
```

**編集内容**:

#### A. com.enablerdao.pon.pro
1. 商品をクリック
2. Localizations セクション → [+] Add Localization
3. **日本語**:
   - Name: `Proプラン`
   - Description: `無制限の契約書作成、PDF電子署名、契約管理、ステータス追跡、レポート機能を利用できます。`
4. **英語（米国）**:
   - Name: `Pro Plan`
   - Description: `Unlimited contract creation, PDF e-signature, contract management, status tracking, and reporting features.`
5. Save

#### B. com.enablerdao.pon.founder
1. 商品をクリック
2. Localizations セクション → [+] Add Localization
3. **日本語**:
   - Name: `ファウンダープラン`
   - Description: `ポンの全機能に加えて、優先サポート、カスタム機能リクエストの優先対応を含みます。`
4. **英語（米国）**:
   - Name: `Founder Plan`
   - Description: `All Pro features plus priority support and priority handling of custom feature requests.`
5. Save

#### C. Terms of Use を確認
1. App Information（左メニュー）
2. Licensing セクション
3. EULA フィールドが `https://pon.enablerdao.com/terms` になっているか確認
4. なければ追加

---

### ステップ 2: IPA をアップロード（5-10 分）

**選択肢 A: Transporter（推奨）**
```bash
# Transporter を起動
open /Applications/Transporter.app

# （ない場合は App Store からダウンロード）
```

1. "+" ボタン
2. ファイルを選択: `/Users/yuki/workspace/pon/ios/build/export/Pon.ipa`
3. Deliver をクリック
4. ビルド処理を待機（通常 5-10 分）

**選択肢 B: App Store Connect Web UI**
1. https://appstoreconnect.apple.com
2. ポン → TestFlight → Builds
3. "+" ボタン
4. IPA を選択・アップロード

---

### ステップ 3: App Store 審査提出（10-15 分）

**前提**: ビルド 15 が TestFlight で "Ready to Submit" に表示されている

**アクセス**: https://appstoreconnect.apple.com

**操作**:
```
ポン
  → App Store（左メニュー）
    → Version 1.0.0 または 1.0.1（なければ作成）
```

**入力フィールド**:

1. **What's New in This Version**（リリースノート）:
```
【バージョン 1.0.1 での改善】
- PDF電子署名機能を追加しました（PencilKitを使用）
- 契約管理機能を改善
- Pro・ファウンダープランのサブスクリプション対応
- IAP メタデータの設定完了
```

2. **Keywords**:
```
ポン, 契約, 署名, 管理, ビジネス
```

3. **Demo Account Required**:
```
No（選択）
```

4. **Build** セクション:
```
ドロップダウン: "Pon 15" を選択
```

5. **Review Notes**（審査チーム向け）:
```
【サブスクリプション機能について】
本アプリは以下のサブスクリプション機能を提供しています：
- Proプラン（¥480/月）: 無制限の契約書作成、PDF電子署名、契約管理、ステータス追跡、レポート機能
- ファウンダープラン（¥980/月）: Pro機能全て + 優先サポート + カスタム機能リクエスト優先対応

【メタデータについて】
- アプリ内では StoreKit 2 を使用して正式にサブスクリプション商品を取得・販売しています。
- IAP メタデータは App Store Connect 管理画面で完全に設定しています。
- Terms of Use（利用規約）: https://pon.enablerdao.com/terms

【デモアカウントについて】
本アプリはログイン不要で動作します。デモアカウントは不要です。
- 任意のセクションのPro機能をタップするとProGateViewが表示されます。
- SettingsタブからもProプランを購入できます。
- 復元ボタンで過去の購入を復元できます。
```

6. **Save（保存）** をクリック

7. **Submit for Review（審査に提出）** ボタンをクリック

8. 確認画面で再度 **Submit** をクリック

---

## 審査期間

**予想期間**: 24-48 時間  
**確認方法**: https://appstoreconnect.apple.com → ポン → Activity

**リジェクト時**:
- Resolution Center で Apple のコメントを確認
- `/Users/yuki/workspace/pon/ios/APP_STORE_SUBMISSION_FIX.md` のトラブルシューティングを参照

**承認時**:
- App Store に自動公開（スケジュール設定可）

---

## チェックリスト

### Web UI 操作
- [ ] App Store Connect にログイン
- [ ] **com.enablerdao.pon.pro** メタデータを設定
  - [ ] 日本語: 名前 = "Proプラン"
  - [ ] 日本語: 説明を入力
  - [ ] 英語: 名前 = "Pro Plan"
  - [ ] 英語: 説明を入力
- [ ] **com.enablerdao.pon.founder** メタデータを設定
  - [ ] 日本語: 名前 = "ファウンダープラン"
  - [ ] 日本語: 説明を入力
  - [ ] 英語: 名前 = "Founder Plan"
  - [ ] 英語: 説明を入力
- [ ] App Information → Licensing: EULA が `https://pon.enablerdao.com/terms` に設定されているか確認

### ビルドアップロード
- [ ] IPA ファイルが存在: `/Users/yuki/workspace/pon/ios/build/export/Pon.ipa`
- [ ] Transporter または Web UI でアップロード
- [ ] ビルド 15 が TestFlight で表示される
- [ ] ビルド状態が "Ready to Submit" に変更される（5-10 分待機）

### App Store 審査提出
- [ ] バージョン 1.0.0 または 1.0.1 を作成
- [ ] What's New を入力
- [ ] Keywords を入力
- [ ] Demo Account Required = No
- [ ] Build = Pon 15 を選択
- [ ] Review Notes を入力
- [ ] Save をクリック
- [ ] **Submit for Review をクリック**
- [ ] 確認画面で再度 Submit をクリック

### 審査期間中
- [ ] 24-48 時間ごとに Activity を確認
- [ ] リジェクト時は Resolution Center を確認

---

## ファイル参照

**詳細な手順書**:
- `/Users/yuki/workspace/pon/ios/APP_STORE_SUBMISSION_FIX.md` — 完全ガイド

**進行状況**:
- `/Users/yuki/workspace/pon/ios/SUBMISSION_STATUS_2026_04_06.md` — 現在の状態とアクション

**API 参考情報**:
- `/Users/yuki/workspace/pon/ios/API_METADATA_SETUP.md` — API の制限と Web UI 推奨理由

**プロジェクト設定**:
- `/Users/yuki/workspace/pon/ios/project.yml` — ビルド番号 15
- `/Users/yuki/workspace/pon/ios/Pon.xcodeproj/` — Xcode プロジェクト
- `/Users/yuki/workspace/pon/ios/build/export/Pon.ipa` — アップロード対象

**ソースコード**:
- `/Users/yuki/workspace/pon/ios/Pon/Sources/ProGateView.swift` — Terms URL リンク
- `/Users/yuki/workspace/pon/ios/Pon/Sources/SubscriptionManager.swift` — StoreKit 2 実装
- `/Users/yuki/workspace/pon/ios/fastlane/metadata/ja/eula_url.txt` — EULA URL（Fastlane）

---

## 予想される結果

### 成功時
✅ App Store に "ポン" が表示  
✅ ユーザーが Pro プランを購入可能  
✅ ファウンダープランも購入可能  

### 再リジェクト時
❌ Resolution Center でリジェクト理由を確認  
→ `APP_STORE_SUBMISSION_FIX.md` のトラブルシューティングで対応  

---

## トラブル時のQ&A

**Q: IAP メタデータの Web UI での作成方法がわからない**  
A: `APP_STORE_SUBMISSION_FIX.md` の「フェーズ 1」を参照

**Q: ビルド 15 がアップロードされない**  
A: Transporter の代わりに Web UI から直接アップロード

**Q: Review Notes に何を書いたらいいか**  
A: このドキュメントの「ステップ 3 → Review Notes」をコピペ

**Q: Terms URL が反映されない**  
A: App Information → Licensing で手動確認・編集

---

## 作業完了予定時刻

- **開始**: 現在
- **メタデータ設定**: +15 分
- **IPA アップロード**: +10 分（ビルド処理 5-10 分待機）
- **審査提出**: +15 分
- **完了**: **約 40 分後（16:25 JST）**

---

**責務**: ポンプロジェクトマネージャー  
**最終確認日**: 2026-04-06 00:50 JST

---

## 成功を祈ります 🎉

Apple の審査が無事に通過し、ポンが App Store で公開されることを期待しています。

何か問題が発生した場合は、以下の順で対応してください:
1. このドキュメントの該当セクションを確認
2. `APP_STORE_SUBMISSION_FIX.md` を確認
3. `SUBMISSION_STATUS_2026_04_06.md` を確認
