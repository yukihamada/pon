# ポン App Store 再審査提出 — リジェクト修正ガイド

## 📋 概要

前回のリジェクト理由を完全に修正し、ポンを App Store に再審査提出するための完全ガイドです。

**リジェクト理由**:
```
Guideline 2.1(b) — "app includes references to Pro plan but the 
associated In-App Purchase products have not been submitted for review"
```

**根本原因**: Pro プラン IAP（`com.enablerdao.pon.pro`）が存在しないまま審査提出された

**修正内容**:
1. ✅ Pro プラン IAP を App Store に作成
2. ✅ Pro プラン・ファウンダープラン両方にローカライゼーション設定
3. ✅ 両方のプランにスクリーンショットを追加
4. ✅ 新しい App Store Version で再審査提出

---

## 📂 ドキュメント構成

| ファイル | 役割 | 対象者 |
|---------|------|--------|
| **PON_IAP_REJECTION_FIX_SUMMARY.md** | 修正内容・概要 | PM / 意思決定者 |
| **IAP_CREATION_AND_RESUBMISSION.md** | 詳細手順・技術仕様 | エンジニア / 検証者 |
| **WEB_UI_STEP_BY_STEP.md** | Web UI 操作ガイド | 実施者（Web UI 操作用） |
| **verify_iap_setup.py** | 自動検証スクリプト | エンジニア（確認用） |
| **RESUBMISSION_README.md** | このファイル | 全員 |

---

## 🚀 実施フロー

### フェーズ 1: 準備（15 分）

1. **このドキュメントを読む** ← 今ここ
2. **PON_IAP_REJECTION_FIX_SUMMARY.md を読む** → リジェクト原因・修正方法の理解
3. **WEB_UI_STEP_BY_STEP.md を開く** → Web UI 操作ガイドをブックマーク

### フェーズ 2: Web UI 操作（30 分）

**実施者**: PM または指定担当者

**ツール**: ブラウザ + WEB_UI_STEP_BY_STEP.md

**操作**:
```
App Store Connect → ポンアプリ
  1. Pro プラン IAP 作成（ステップ 1）
  2. ローカライゼーション追加（ステップ 2）
  3. スクリーンショット追加（ステップ 3）
  4. 価格設定（ステップ 4）
  5. Pro プラン審査提出（ステップ 5）
  6. 既存バージョン削除（ステップ 6）
  7. 新バージョン 1.0.1 作成（ステップ 7-12）
  8. 最終審査提出（ステップ 12）
```

**予想完了時刻**: 2026-04-07 15:00 JST

### フェーズ 3: 検証（5 分）

**実施者**: エンジニア

**実行**:
```bash
cd /Users/yuki/workspace/pon/ios
python3 verify_iap_setup.py
```

**期待される出力**:
```
✅ IAP セットアップ: 完了
✅ App Store Version: 審査提出完了

🎉 全ての設定が完了しました！
```

### フェーズ 4: 待機・監視（24-48 時間）

**監視項目**: App Store Connect Activity タブ

**期待される状態遷移**:
```
1. Version 1.0.1 提出直後 → 「Processing」
2. 数分後                   → 「In Review」
3. 24-48 時間後             → 「Approved」 or 「Rejected」
```

**確認場所**: https://appstoreconnect.apple.com → ポン → Activity

---

## 🔑 重要なポイント

### 1. Web UI は自動化不可
- IAP の作成・ローカライゼーション・スクリーンショット追加は **Web UI のみ**
- API では読取・状態確認のみ可能
- 手作業が避けられません（Apple の設計）

### 2. ビルド 16 は使い回し
- 既にアップロード済みのビルド 16 を複数バージョンで使用可能
- 新しいビルドが必要ない限り、Build 16 を Version 1.0.1, 1.0.2... で再利用可

### 3. IAP 審査は別プロセス
- Pro プラン IAP と App Store Version は独立した審査
- Pro プラン IAP は「Submit for Review」で別途審査に進む
- Version 1.0.1 は Pro プラン完成後に提出

### 4. ローカライゼーション必須
- 日本語（ja）と英語（en-US）の両方が必須
- 片方でも欠けるとリジェクト対象
- 既に設定済みのファウンダープラン参照: ja, en-US ✅

### 5. スクリーンショット必須
- 既存の `iap_screenshot.png` (131 KB) を両 IAP で使用可能
- スクリーンショットなしでの審査提出は不可
- 既にファウンダープラン用で設定済み ✅

---

## ❌ よくある失敗

### × Pro プラン作成忘れ
**症状**: Version 1.0.1 を提出 → 「Pro plan not found」でリジェクト

**予防**: WEB_UI_STEP_BY_STEP.md の ステップ 1-5 を厳密に実行

### × ローカライゼーション未設定
**症状**: リジェクト「Localization not available」

**予防**: ステップ 2 で ja, en-US 両方を必ず追加

### × スクリーンショット未設定
**症状**: リジェクト「Screenshot required」

**予防**: ステップ 3 で `iap_screenshot.png` を追加

### × App Store Version に Build を選択していない
**症状**: 提出不可「Build is required」

**予防**: ステップ 9 で Build 16 を必ず選択

### × Review Notes が不十分
**症状**: リジェクト「Provide more details」

**予防**: ステップ 10 のテンプレートをそのまま使用

---

## 🔧 トラブルシューティング

### Q: Web UI でエラーメッセージが出た

**A**: 

1. ブラウザキャッシュをクリア
   ```
   Cmd+Shift+Delete → キャッシュを削除
   ```

2. 別のブラウザで試す（Safari / Chrome）

3. App Store Connect ログアウト → 再ログイン

4. ネットワーク接続を確認

### Q: ローカライゼーション追加後に反映されない

**A**:

1. ブラウザをリロード（Cmd+R）
2. 5-10 分待つ（キャッシュの反映遅延）
3. 再度確認

### Q: ビルド 16 が Version 1.0.1 で選択できない

**A**:

1. Build 16 のステップが「Ready to Submit」以上か確認
   - TestFlight → Builds で確認
   
2. Build が正しくアップロードされているか確認
   ```bash
   cd /Users/yuki/workspace/pon/ios
   python3 verify_iap_setup.py
   ```

3. 数分待ってから再度選択を試す

### Q: 審査に落ちた（Rejected）

**A**:

1. Resolution Center でコメント確認
   ```
   Apps → ポン → Activity → 最新のリジェクトをクリック
   ```

2. 指摘内容を記録（スクリーンショット推奨）

3. 必要に応じてコード修正 / メタデータ修正

4. 新バージョン 1.0.2 で再提出

---

## 📊 予想スケジュール

| 日時 | イベント | 担当 |
|------|---------|------|
| 2026-04-07 14:00 | Web UI 操作開始 | PM |
| 2026-04-07 14:30 | Web UI 操作完了 | PM |
| 2026-04-07 14:40 | API 検証スクリプト実行 | Engineer |
| 2026-04-07 15:00 | 確認完了 | All |
| 2026-04-07 15:00～ | Activity タブで「In Review」確認開始 | All |
| **2026-04-09 09:00** | **審査完了予想（最短 24 時間後）** | Apple |
| 2026-04-09 14:00 | **審査完了予想（最長 48 時間後）** | Apple |
| 2026-04-09 14:30 | Manual Release でリリース | PM |

---

## 📞 サポート

### 実施前の質問
1. **手順がわからない** → WEB_UI_STEP_BY_STEP.md を参照
2. **API の詳細知りたい** → IAP_CREATION_AND_RESUBMISSION.md を参照

### 実施中のトラブル
1. **Web UI でエラー** → トラブルシューティング 参照
2. **リジェクトされた** → トラブルシューティング「審査に落ちた」参照

### 事後確認
1. **設定完了か確認したい**
   ```bash
   python3 /Users/yuki/workspace/pon/ios/verify_iap_setup.py
   ```

---

## 📁 ファイル一覧

```
/Users/yuki/workspace/pon/ios/

# 手順ドキュメント（このセット）
├── RESUBMISSION_README.md              ← このファイル
├── PON_IAP_REJECTION_FIX_SUMMARY.md    ← 修正概要
├── IAP_CREATION_AND_RESUBMISSION.md    ← 詳細手順
├── WEB_UI_STEP_BY_STEP.md              ← Web UI ガイド

# 検証ツール
├── verify_iap_setup.py                 ← 自動検証スクリプト

# プロジェクトファイル
├── project.yml                         ← xcodegen 設定 (CURRENT_PROJECT_VERSION: 16)
├── Pon/Info.plist                      ← アプリ設定 (CFBundleVersion: 16)
├── iap_screenshot.png                  ← IAP スクリーンショット (131 KB)
├── fastlane/metadata/                  ← ストア メタデータ

# 既存ドキュメント
├── PON_FINAL_STATUS.md
├── SUBMISSION_STATUS_2026_04_06.md
├── APP_STORE_SUBMISSION_FIX.md
├── FINAL_SUBMISSION_CHECKLIST.md
└── SUBMISSION_PROGRESS_2026_04_07.md
```

---

## ✅ チェックリスト

### 前日の確認
- [ ] このドキュメント読了
- [ ] WEB_UI_STEP_BY_STEP.md ブックマーク
- [ ] App Store Connect ログイン確認
- [ ] ブラウザ整理（余分なタブ閉じる）

### Web UI 操作中
- [ ] Pro プラン IAP 作成完了
- [ ] ローカライゼーション ja, en-US 追加完了
- [ ] スクリーンショット追加完了
- [ ] 価格設定完了
- [ ] Pro プラン審査提出完了
- [ ] 既存 Version 1.0 削除完了
- [ ] Version 1.0.1 作成完了
- [ ] メタデータ入力完了
- [ ] Build 16 選択完了
- [ ] Review Notes 入力完了
- [ ] 最終審査提出完了

### 操作後の確認
- [ ] verify_iap_setup.py 実行
- [ ] 全項目 ✅ 確認
- [ ] Activity タブで「In Review」確認（5-10 分後）

### 待機中
- [ ] 毎日 Activity タブ確認（朝・夕方）
- [ ] リジェクト通知があれば Resolution Center で確認
- [ ] 通知がなければ 24-48 時間待機

---

## 🎯 成功の定義

**全て達成したら成功です**:

✅ Pro プラン IAP が App Store に存在  
✅ Pro プラン・ファウンダープラン両方にローカライゼーション設定  
✅ 両プランにスクリーンショット設定  
✅ Version 1.0.1 が「Approved」を獲得  
✅ 本番リリース完了

---

## 📞 連絡先

**質問・問題報告**:
- GitHub Issues: [pon リポジトリ](https://github.com/yukihamada/pon/issues)
- Email: [project contact]

---

**最後更新**: 2026-04-07  
**ステータス**: 実装準備完了  
**次のアクション**: Web UI 操作実施  
**担当**: ポンプロジェクトマネージャー
