# ポン IAP リジェクト修正 — 詳細手順（2026-04-07）

## 問題分析

前回のリジェクト理由: **「app includes references to Pro plan but the associated In-App Purchase products have not been submitted for review」**

### 根本原因
App Store に **Pro プラン IAP（com.enablerdao.pon.pro）が存在しない** ため、審査に提出できません。

現在の状況：
- ✅ **ファウンダープラン (com.enablerdao.pon.founder)**
  - ローカライゼーション設定: ja, en-US ✅
  - スクリーンショット: ✅ 設定済み
  - 状態: READY_TO_SUBMIT

- ❌ **Pro プラン (com.enablerdao.pon.pro)**
  - 存在しません（作成が必要）

- ❌ **App Store Version 1.0**
  - 状態: REJECTED
  - 新バージョン作成が必要

## 修正手順

### ステップ 1: Pro プラン IAP を作成（Web UI）

App Store Connect にログイン:
```
https://appstoreconnect.apple.com
```

操作：
1. **Apps** → **ポン** をクリック
2. 左メニュー → **In-App Purchases** をクリック
3. **+** ボタンをクリック（新規 IAP 作成）
4. **Type** = `Non-Consumable` を選択
5. **Product ID** = `com.enablerdao.pon.pro` と入力
6. **Reference Name** = `Pon Pro Plan` と入力
7. **Price** = `480 JPY/month` (スクリーンショット参考)
   - 実際には月額では Renewal → Subscription の設定が必要
8. **Status** → **Submit for Review** をクリック（設定完了後）

**重要**: IAP の作成後、必ず以下を設定:

#### 1a. ローカライゼーション追加

Pro プラン作成直後、同じ画面で:

1. **Localizations** タブ
2. **+ Add Localization** をクリック
3. **日本語 (ja)** を選択:
   - **Name**: `Proプラン`
   - **Description**: `無制限の契約書作成、PDF電子署名、契約管理、ステータス追跡、レポート機能を利用できます。`
   - **Save**
4. 同じく **英語 (en-US)** を選択:
   - **Name**: `Pro Plan`
   - **Description**: `Unlimited contract creation, PDF e-signature, contract management, status tracking, and reporting features.`
   - **Save**

#### 1b. スクリーンショット追加

同じく Pro プラン画面で:

1. **App Store Review Screenshot** セクション
2. **+ Add Screenshot** をクリック
3. スクリーンショット画像を選択:
   - `/Users/yuki/workspace/pon/ios/iap_screenshot.png` を使用
4. **Save**

#### 1c. 価格設定

Pro プラン画面で:

1. **Pricing and Availability**
2. **Price** = 「Base Territory」を選択
3. Japan の価格 = ¥480/month （または計画に合わせて変更）
4. **Save**

#### 1d. 審査提出

Pro プラン画面の上部で:

1. **Submit for Review** ボタンをクリック
2. 確認メッセージで再度 **Submit** をクリック

**予想完了時刻**: 設定完了から 5-10 分後

### ステップ 2: 既存バージョン 1.0 をキャンセル（Web UI）

ポン アプリメニュー:
1. 左メニュー → **App Store**
2. **Version 1.0** を選択（REJECTED と表示）
3. **Release Information** セクション
4. 左上の **⋯** (More) メニュー → **Reject** または **Delete**
   - 古いリジェクト版なので削除推奨

### ステップ 3: 新規 App Store Version を作成（Web UI）

ポン アプリメニュー:
1. 左メニュー → **App Store**
2. **+ Add Version** をクリック
3. **Platform**: iOS
4. **Release Type**: Manual Release
5. **Version Number**: `1.0.1` （1.0 より新しい番号）

#### 3a. メタデータ設定

**What's New in This Version**:
```
【バージョン 1.0.1 での改善】
- Pro・ファウンダープランのサブスクリプション対応を完了
- IAP メタデータの設定完了
- PDF電子署名機能を搭載
- 契約管理機能を改善
```

**Keywords**:
```
ポン, 契約, 署名, 管理, ビジネス, 電子契約, PDF
```

**Category**: `Business` または `Productivity`

**Privacy Policy URL**: `https://pon.enablerdao.com/privacy`

**Terms of Use**: `https://pon.enablerdao.com/terms`

**Demo Account Required**: `No`

#### 3b. ビルド選択

同じ画面で:

1. **Build** セクション
2. **+ Select** をクリック
3. **Build 16** を選択（最新）
4. **Save**

#### 3c. 審査用ノート

**Review Notes** セクションに:

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

#### 3d. スクリーンショット・プレビュー

必要であれば:

1. **Screenshots** セクション
2. iPhone スクリーンショット 3-5 枚追加
   - プロゲート画面
   - サブスクリプション画面
   - 契約一覧画面
   など

#### 3e. 保存

画面下部の **Save** をクリック

### ステップ 4: App Store 審査提出（Web UI）

バージョン 1.0.1 詳細画面:

1. 右上の **Submit for Review** ボタンをクリック
2. チェックリスト:
   - [ ] All required fields filled
   - [ ] IAP configured (Pro + Founder)
   - [ ] Build selected (Build 16)
   - [ ] Review Notes completed
3. 確認メッセージで **Submit** をクリック

**予想完了時刻**: 2026-04-07 18:00 JST 前後

### ステップ 5: 審査期間中の確認

**Activity** タブで進捗確認:
- `In Review` — 審査中（24-48 時間）
- `Approved` — 承認！ 🎉
- `Ready to Release` — リリース待機中
- `Rejected` — リジェクト（Resolution Center で理由確認）

## API による再確認（Terminal）

### ステップ 1-3 完了後、以下で確認

```bash
cat > /tmp/verify_iap_after_creation.py << 'EOF'
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
print("ポン IAP 最終確認（Web UI 設定後）")
print("=" * 60)

# IAP 確認
resp = make_request('GET', '/v1/apps/6761041004/inAppPurchasesV2', token)
print("\n【In-App Purchases】")
if resp and 'data' in resp:
    for iap in resp['data']:
        product_id = iap['attributes']['productId']
        state = iap['attributes']['state']
        print(f"✅ {product_id}: {state}")
else:
    print("❌ 取得失敗")

# App Store Version 確認
resp = make_request('GET', '/v1/apps/6761041004/appStoreVersions', token)
print("\n【App Store Versions】")
if resp and 'data' in resp:
    for ver in resp['data']:
        version_string = ver['attributes']['versionString']
        state = ver['attributes']['appStoreState']
        print(f"✅ {version_string}: {state}")
else:
    print("❌ 取得失敗")

print("\n" + "=" * 60)
print("全て ✅ なら提出準備完了")
EOF

python3 /tmp/verify_iap_after_creation.py
```

## チェックリスト

### Web UI 操作完了時点
- [ ] Pro プラン IAP 作成完了
- [ ] Pro プラン ローカライゼーション (ja, en-US) 設定
- [ ] Pro プラン スクリーンショット 追加
- [ ] Pro プラン 価格設定（¥480/月）
- [ ] Pro プラン 審査提出
- [ ] 既存バージョン 1.0 (REJECTED) 削除
- [ ] 新バージョン 1.0.1 作成完了
- [ ] バージョン 1.0.1 → Build 16 選択
- [ ] バージョン 1.0.1 → Review Notes 入力
- [ ] バージョン 1.0.1 → App Store 審査提出

### 審査期間中
- [ ] Activity タブで `In Review` 確認
- [ ] 24-48 時間待機

### リジェクト時
- [ ] Resolution Center でコメント確認
- [ ] 指摘内容に対応
- [ ] 新バージョン（1.0.2）で再提出

## ファイル参照

- **IAP スクリーンショット**: `/Users/yuki/workspace/pon/ios/iap_screenshot.png`
- **プロジェクト設定**: `/Users/yuki/workspace/pon/ios/project.yml`
- **Info.plist**: `/Users/yuki/workspace/pon/ios/Pon/Info.plist`
- **ストア設定**: `/Users/yuki/workspace/pon/ios/fastlane/metadata/`

---

**最終更新**: 2026-04-07 13:45 JST  
**責務**: ポンプロジェクトマネージャー
