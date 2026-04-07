# ポン App Store IAP リジェクト修正 — 実行サマリー（2026-04-07 14:45 JST）

## 🎯 ミッション

ポンの App Store 審査リジェクト（Guideline 2.1(b)）を修正し、再審査提出するための完全な実行ガイドを準備しました。

---

## ✅ 完了した準備

### 1. リジェクト原因の完全特定
**原因**: Pro プラン IAP（`com.enablerdao.pon.pro`）が App Store に存在しないまま審査提出された

**証拠**: API で確認済み
- ✅ ファウンダープラン存在（com.enablerdao.pon.founder）
- ❌ Pro プラン存在しない（com.enablerdao.pon.pro）

### 2. 実行ガイドの完全作成

#### 📄 ドキュメント
| ファイル | 内容 |
|---------|------|
| **RESUBMISSION_README.md** | 📋 全体マスターガイド |
| **PON_IAP_REJECTION_FIX_SUMMARY.md** | 🔍 問題分析と解決方法 |
| **IAP_CREATION_AND_RESUBMISSION.md** | 📋 技術詳細手順 |
| **WEB_UI_STEP_BY_STEP.md** | 🖥️ Web UI 操作ガイド（13 ステップ） |
| **EXECUTION_SUMMARY.md** | 📊 このファイル |

#### 🔧 ツール
| ファイル | 役割 |
|---------|------|
| **verify_iap_setup.py** | 自動検証スクリプト |

### 3. Git にコミット完了
```bash
9aa2416 Add App Store IAP resubmission guides and verification script.
```

---

## 📊 現在の状態（2026-04-07 14:45 検証）

### IAP 製品状態
```
✅ ファウンダープラン (com.enablerdao.pon.founder)
   - ローカライゼーション: ja, en-US ✅
   - スクリーンショット: ✅
   - 状態: READY_TO_SUBMIT

❌ Pro プラン (com.enablerdao.pon.pro)
   - 存在しません（Web UI で作成必須）
```

### App Store Version 状態
```
⚠️ Version 1.0
   - 状態: REJECTED（前回のリジェクト）
   - 削除必須

❌ Version 1.0.1
   - 存在しません（作成必須）
```

### ビルド状態
```
✅ Build 16
   - アップロード済み（984 KB）
   - CURRENT_PROJECT_VERSION: 16
   - 状態: Ready to Submit
```

---

## 🚀 実施フロー

### フェーズ 1: Web UI 操作（PM / 指定担当者）

**所要時間**: 約 30 分

**ツール**: ブラウザ + WEB_UI_STEP_BY_STEP.md

**操作内容**（13 ステップ）:

1. ✍️ Pro プラン IAP 作成
2. ✍️ ローカライゼーション追加（ja, en-US）
3. ✍️ スクリーンショット追加
4. ✍️ 価格設定（¥480/月）
5. ✍️ Pro プラン審査提出
6. 🗑️ 既存バージョン 1.0 削除
7. ✍️ 新バージョン 1.0.1 作成
8. ✍️ メタデータ設定（What's New等）
9. ✍️ ビルド 16 選択
10. ✍️ Review Notes 入力
11. ✍️ 保存
12. ✍️ 審査提出
13. ✅ 確認

**予想実施時刻**: 2026-04-07 15:00-15:30 JST

### フェーズ 2: 自動検証（エンジニア）

**所要時間**: 2 分

**実行コマンド**:
```bash
cd /Users/yuki/workspace/pon/ios
python3 verify_iap_setup.py
```

**期待される出力** (操作完了後):
```
✅ IAP セットアップ: 完了
✅ App Store Version: 審査提出完了

🎉 全ての設定が完了しました！
```

**予想実行時刻**: 2026-04-07 15:45 JST

### フェーズ 3: 審査期間（Apple）

**所要時間**: 24-48 時間

**監視**: Activity タブで状態確認

**期待される状態遷移**:
```
提出直後  → Processing（数分）
           → In Review（審査開始）
           → Approved or Rejected（24-48 時間後）
```

**予想審査完了**: 2026-04-09 15:00 JST 前後

### フェーズ 4: リリース（PM）

**所要時間**: 5 分

**操作**:
```
Version 1.0.1 → Manual Release で本番リリース
```

**予想リリース**: 2026-04-09 16:00 JST

---

## 📋 実行チェックリスト

### 実施前
- [ ] RESUBMISSION_README.md 読了
- [ ] WEB_UI_STEP_BY_STEP.md をブックマーク
- [ ] App Store Connect ログイン確認

### Web UI 操作中（PM / 担当者）
- [ ] ステップ 1: Pro プラン IAP 作成完了
- [ ] ステップ 2: ローカライゼーション ja, en-US 追加完了
- [ ] ステップ 3: スクリーンショット追加完了
- [ ] ステップ 4: 価格設定完了
- [ ] ステップ 5: Pro プラン審査提出完了
- [ ] ステップ 6: Version 1.0 削除完了
- [ ] ステップ 7-11: Version 1.0.1 作成・設定完了
- [ ] ステップ 12: 最終審査提出完了

### 操作後検証（エンジニア）
- [ ] `python3 verify_iap_setup.py` 実行
- [ ] 出力が全て ✅ であることを確認
- [ ] Activity タブで「In Review」確認（5-10 分後）

### 待機中（全員）
- [ ] Activity タブで毎日状態確認
- [ ] リジェクト通知なし → 24-48 時間待機
- [ ] リジェクト通知あり → Resolution Center で理由確認

### リリース前（PM）
- [ ] Approved 確認
- [ ] Manual Release でリリース実行

---

## 🔑 重要な注意事項

### 1. Web UI 操作は自動化不可
- IAP 作成・ローカライゼーション・スクリーンショット追加は **Web UI のみ**
- API では読取・状態確認のみ可能
- 手作業が避けられません（Apple の設計）

### 2. 各ステップを厳密に実行
- 特に ステップ 2, 3, 9, 10 を漏らさないこと
- チェックリストを確認しながら進める

### 3. ローカライゼーション・スクリーンショットは必須
- 片方でも欠けるとリジェクト対象
- WEB_UI_STEP_BY_STEP.md の例文をそのまま使用推奨

### 4. Review Notes の詳細さが重要
- テンプレートをそのまま使用（変更不要）
- Apple のガイドラインレビュアーが確認する
- 不十分だとリジェクト対象

---

## 📞 トラブルシューティング

### 問題が発生したら

1. **WEB_UI_STEP_BY_STEP.md の「トラブルシューティング」セクション確認**
2. **API でステータス確認**
   ```bash
   python3 verify_iap_setup.py
   ```
3. **必要に応じて手順をリトライ**

### リジェクトされた場合

1. **Resolution Center でコメント確認**
   ```
   Activity → 最新のリジェクト → コメント確認
   ```
2. **指摘内容に対応**
   - コード修正が必要な場合 → 新しいビルド作成
   - メタデータ修正で済む場合 → Version 1.0.2 で再提出
3. **新バージョンで再審査提出**

---

## 📊 予想スケジュール

| 日時 | マイルストーン | 所要時間 | 累計 |
|------|--------------|--------|------|
| 2026-04-07 15:00 | Web UI 操作開始 | - | - |
| 2026-04-07 15:30 | Web UI 操作完了 | 30 分 | 30 分 |
| 2026-04-07 15:45 | API 検証完了 | 2 分 | 32 分 |
| **2026-04-07～** | **審査期間（待機）** | **24-48 h** | **+24 h** |
| **2026-04-09 09:00** | **審査完了予想（最短）** | - | **58 時間** |
| **2026-04-09 15:00** | **審査完了予想（平均）** | - | **64 時間** |
| 2026-04-09 16:00 | Manual Release リリース | 5 分 | **〜 64 時間** |

---

## 📁 ファイル構成

```
/Users/yuki/workspace/pon/ios/

【実行ガイド】
├── RESUBMISSION_README.md              ← 全体マスターガイド
├── PON_IAP_REJECTION_FIX_SUMMARY.md    ← 問題分析
├── IAP_CREATION_AND_RESUBMISSION.md    ← 技術詳細
├── WEB_UI_STEP_BY_STEP.md              ← Web UI ガイド（実施書）
├── EXECUTION_SUMMARY.md                ← このファイル

【検証ツール】
├── verify_iap_setup.py                 ← 自動検証スクリプト

【プロジェクト】
├── project.yml                         ← (CURRENT_PROJECT_VERSION: 16)
├── Pon/Info.plist                      ← (CFBundleVersion: 16)
├── iap_screenshot.png                  ← IAP スクリーンショット
└── fastlane/metadata/                  ← ストア メタデータ
```

---

## ✨ 次のアクション

### 即座に実施（必須）
1. **RESUBMISSION_README.md を読む** → 概要把握
2. **WEB_UI_STEP_BY_STEP.md をブックマーク** → 実施時に参照
3. **実施日時を PM と合意** → スケジュール確定

### 実施時（PM / 担当者）
1. **WEB_UI_STEP_BY_STEP.md に従って 13 ステップを実行**
2. **完了後、エンジニアに連絡**

### 実施後（エンジニア）
1. **`python3 verify_iap_setup.py` で確認**
2. **結果を PM に報告**

### 待機中（全員）
1. **毎日 Activity タブで状態確認**
2. **変化があれば Slack で共有**

---

## 🎉 成功の条件

全て達成したら成功：

- ✅ Pro プラン IAP が App Store に存在
- ✅ 両プランにローカライゼーション設定
- ✅ 両プランにスクリーンショット設定
- ✅ Version 1.0.1 が「Approved」獲得
- ✅ 本番リリース完了

---

**最後更新**: 2026-04-07 14:45 JST  
**責務**: ポンプロジェクトマネージャー  
**ステータス**: 実行準備完了 ✅  
**次のアクション**: Web UI 操作（PM）+ API 検証（エンジニア）
