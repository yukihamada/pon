# ポン App Store IAP リジェクト修正 — 実行サマリー（2026-04-07）

## リジェクト原因の特定（✅ 完了）

**前回のリジェクト理由**:
```
IAPが審査に提出されていない
Guideline 2.1(b) — "app includes references to Pro plan but the 
associated In-App Purchase products have not been submitted for review"
```

**根本原因特定**:
1. アプリコード内で Pro プランを参照している（ProGateView.swift 等）
2. しかし **Pro プラン IAP (com.enablerdao.pon.pro) が App Store に存在しない**
3. App Store Version 1.0 を提出したが、IAP なしで審査に引っかかった

## 現在の状況（API 確認済み）

### ✅ 設定完了
| 項目 | 状態 | 詳細 |
|------|------|------|
| ファウンダープラン IAP | ✅ 作成 | com.enablerdao.pon.founder |
| ローカライゼーション | ✅ 完備 | ja, en-US |
| スクリーンショット | ✅ 設定済み | IAP Review Screenshot 追加済み |
| ビルド 16 | ✅ アップロード | サイズ 984 KB, CURRENT_PROJECT_VERSION: 16 |

### ❌ 必須作成
| 項目 | 状態 | アクション |
|------|------|----------|
| **Pro プラン IAP** | ❌ 未作成 | **Web UI で作成必須** |
| App Store Version 1.0 | ⚠️ REJECTED | 削除し、新バージョン 1.0.1 で再提出 |

## 修正手順（Web UI 必須）

### フェーズ 1: Pro プラン IAP 作成（API 不可、Web UI のみ）

**時間目安**: 15-20 分

**Web UI**: https://appstoreconnect.apple.com

**操作**:

#### 1. Pro プラン IAP 作成
```
Apps → ポン → In-App Purchases → [+] Add
Type: Non-Consumable
Product ID: com.enablerdao.pon.pro
Reference Name: Pon Pro Plan
Price: ¥480/month (or as planned)
```

#### 2. ローカライゼーション追加
Pro プラン詳細画面 → Localizations → [+] Add Localization

**日本語 (ja)**:
- Name: `Proプラン`
- Description: `無制限の契約書作成、PDF電子署名、契約管理、ステータス追跡、レポート機能を利用できます。`

**英語 (en-US)**:
- Name: `Pro Plan`
- Description: `Unlimited contract creation, PDF e-signature, contract management, status tracking, and reporting features.`

#### 3. スクリーンショット追加
Pro プラン詳細画面 → App Store Review Screenshot → [+] Add Screenshot

ファイル: `/Users/yuki/workspace/pon/ios/iap_screenshot.png`

#### 4. Pro プラン 審査提出
Pro プラン詳細画面 → [Submit for Review] ボタン

### フェーズ 2: App Store Version 再作成（Web UI）

**時間目安**: 10-15 分

#### 1. 既存バージョン 1.0 をキャンセル
```
Apps → ポン → App Store → Version 1.0 (REJECTED)
[⋯] More → Delete
```

#### 2. 新バージョン 1.0.1 作成
```
Apps → ポン → App Store → [+] Add Version
Platform: iOS
Release Type: Manual Release
Version Number: 1.0.1
```

#### 3. メタデータ設定

**What's New**:
```
【バージョン 1.0.1 での改善】
- Pro・ファウンダープランのサブスクリプション対応を完了
- IAP メタデータの設定完了
- PDF電子署名機能を搭載
- 契約管理機能を改善
```

**Keywords**: `ポン, 契約, 署名, 管理, ビジネス, 電子契約, PDF`

**Category**: Business or Productivity

**Privacy Policy URL**: `https://pon.enablerdao.com/privacy`

**Terms of Use**: `https://pon.enablerdao.com/terms`

**Demo Account Required**: No

#### 4. ビルド選択
Version 1.0.1 詳細 → Build → [+] Select → Build 16

#### 5. 審査用レビューノート
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

### フェーズ 3: App Store 審査提出（Web UI）

**時間目安**: 5 分

**操作**:

```
Apps → ポン → App Store → Version 1.0.1
[Submit for Review] ボタンをクリック
確認画面で再度 [Submit] をクリック
```

## 審査期間中の確認

**進捗確認場所**: Activity タブ

| 状態 | 意味 | 次のアクション |
|------|------|-------------|
| `In Review` | 審査中 | 24-48 時間待機 |
| `Approved` | 承認！🎉 | Manual Release → [Release] 選択 |
| `Ready to Release` | リリース待機 | Manual Release だから手動リリース |
| `Rejected` | リジェクト | Resolution Center でコメント確認 → 修正 → 再提出 |

## リジェクト時の対応（テンプレート）

### Step 1: リジェクト理由確認
```
Apps → ポン → Activity
最新のレジェクトメッセージをクリック → Resolution Center で詳細確認
```

### Step 2: コードまたはメタデータを修正
例：
- IAP の説明文が不十分 → Web UI で修正
- Pro 機能の実装が不完全 → コード修正 → 新しいビルド作成
- スクリーンショットが不適切 → 新しいスクリーンショット準備

### Step 3: 新バージョンで再提出
```
新バージョン 1.0.2 を作成 → メタデータ/ビルド修正 → [Submit for Review]
```

## 重要な注意事項

### API では IAP 作成・削除不可
- IAP の作成・ローカライゼーション・スクリーンショット追加は **Web UI のみ**
- API では IAP の読取・状態確認のみ可能

### ビルド番号は変更不要
- 現在ビルド 16 が用意済み
- 新しいビルドが必要ない限り、同じビルド 16 を複数バージョンで使用可能

### 価格設定の確認
- Pro プラン: ¥480/month （プロジェクトの設計に従う）
- ファウンダープラン: ¥980/month

## チェックリスト

### Web UI 実行前
- [ ] このドキュメントを読了
- [ ] IAP_CREATION_AND_RESUBMISSION.md で詳細確認
- [ ] App Store Connect ログイン確認

### Web UI 実行中
- [ ] Pro プラン IAP 作成完了
- [ ] Pro プラン ローカライゼーション (ja, en-US) 設定 ✅
- [ ] Pro プラン スクリーンショット 追加 ✅
- [ ] Pro プラン 価格設定（¥480/month） ✅
- [ ] Pro プラン 審査提出 ✅
- [ ] 既存バージョン 1.0 (REJECTED) 削除 ✅
- [ ] 新バージョン 1.0.1 作成 ✅
- [ ] バージョン 1.0.1 → Build 16 選択 ✅
- [ ] バージョン 1.0.1 → Review Notes 入力 ✅
- [ ] バージョン 1.0.1 → App Store 審査提出 ✅

### 審査期間中
- [ ] Activity タブで `In Review` 確認
- [ ] 24-48 時間待機

## API で設定確認（Terminal）

Web UI 操作完了後、以下を実行して確認：

```bash
cat > /tmp/verify_pon_iap.py << 'PYEOF'
#!/usr/bin/env python3
import sys, jwt, json, time, subprocess
from pathlib import Path

def generate_token():
    key_path = Path.home() / '.appstoreconnect/private_keys/AuthKey_5KT46G9Y29.p8'
    with open(key_path, 'r') as f:
        key = f.read()
    now = int(time.time())
    payload = {
        'iss': 'e0d22675-afb3-45f0-a821-06b477f44da0',
        'iat': now,
        'exp': now + 600,
        'aud': 'appstoreconnect-v1'
    }
    return jwt.encode(payload, key, algorithm='ES256', headers={'kid': '5KT46G9Y29'})

def make_request(method, endpoint, token, data=None):
    url = f"https://api.appstoreconnect.apple.com{endpoint}"
    cmd = ['curl', '-s', '-X', method, url, '-H', f'Authorization: Bearer {token}', '-H', 'Content-Type: application/json']
    if data:
        cmd += ['-d', json.dumps(data)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(result.stdout) if result.stdout.strip() else None

token = generate_token()
print("ポン IAP 最終確認\n" + "=" * 60)

# IAP 確認
resp = make_request('GET', '/v1/apps/6761041004/inAppPurchasesV2', token)
print("\n【In-App Purchases】")
if resp and 'data' in resp:
    for iap in resp['data']:
        product_id = iap['attributes']['productId']
        state = iap['attributes']['state']
        print(f"  ✅ {product_id}: {state}")
        
        # ローカライゼーション確認
        iap_id = iap['id']
        loc_resp = make_request('GET', f'/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations', token)
        if loc_resp and 'data' in loc_resp:
            locales = [loc['attributes']['locale'] for loc in loc_resp['data']]
            print(f"     └ ローカライゼーション: {', '.join(locales)}")

# App Store Version 確認
resp = make_request('GET', '/v1/apps/6761041004/appStoreVersions', token)
print("\n【App Store Versions】")
if resp and 'data' in resp:
    for ver in resp['data']:
        version_string = ver['attributes']['versionString']
        state = ver['attributes']['appStoreState']
        print(f"  ✅ {version_string}: {state}")

print("\n" + "=" * 60)
print("\n全て ✅ かつ status が IN_REVIEW なら提出成功！\n")
PYEOF

python3 /tmp/verify_pon_iap.py
```

## ファイル参照

- **詳細手順**: `/Users/yuki/workspace/pon/ios/IAP_CREATION_AND_RESUBMISSION.md`
- **IAP スクリーンショット**: `/Users/yuki/workspace/pon/ios/iap_screenshot.png`
- **プロジェクト設定**: `/Users/yuki/workspace/pon/ios/project.yml`
- **Info.plist**: `/Users/yuki/workspace/pon/ios/Pon/Info.plist`
- **ストア設定**: `/Users/yuki/workspace/pon/ios/fastlane/metadata/`

## サポート

**問題が発生した場合**:

1. **IAP 作成失敗** → Web UI のエラーメッセージ確認 → Apple 公式ドキュメント参照
2. **バージョン審査リジェクト** → Resolution Center の詳細メッセージを必ず確認
3. **ローカライゼーション未反映** → Web UI で保存後 5-10 分待機してから再確認

---

**最終更新**: 2026-04-07 14:00 JST  
**責務**: ポンプロジェクトマネージャー  
**次のマイルストーン**: Web UI 操作完了 → 審査提出 → 24-48 時間待機 → 承認
