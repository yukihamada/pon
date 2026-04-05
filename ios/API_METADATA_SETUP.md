# App Store Connect REST API を使用した IAP メタデータ設定

**注**: このドキュメントは参考情報です。Web UI での設定が推奨されます。

---

## API エンドポイント構造

### App Store Connect API の制限

現在、App Store Connect REST API の `inAppPurchaseLocalizations` エンドポイントには複数の問題があります:

1. **ローカライゼーション取得**: `/inAppPurchases/{id}/inAppPurchaseLocalizations` → 404 Not Found
2. **ローカライゼーション作成**: `inAppPurchase` リレーションシップは無効

---

## Web UI での設定（推奨方法）

### ステップバイステップ

#### 1. App Store Connect にアクセス
```
https://appstoreconnect.apple.com
```

#### 2. ポン アプリを選択
- Apps > ポン - 電子契約・署名

#### 3. In-App Purchases セクション
- 左メニュー: **In-App Purchases**

#### 4. com.enablerdao.pon.pro を編集

1. 商品をクリック
2. **Localizations** セクション
3. **[+] Add Localization** をクリック

**日本語 (ja)**:
- Language: Japanese
- Name: `Proプラン`
- Description: `無制限の契約書作成、PDF電子署名、契約管理、ステータス追跡、レポート機能を利用できます。`

**英語 (en-US)**:
- Language: English (United States)
- Name: `Pro Plan`
- Description: `Unlimited contract creation, PDF e-signature, contract management, status tracking, and reporting features.`

#### 5. com.enablerdao.pon.founder を編集

**日本語 (ja)**:
- Language: Japanese
- Name: `ファウンダープラン`
- Description: `ポンの全機能に加えて、優先サポート、カスタム機能リクエストの優先対応を含みます。`

**英語 (en-US)**:
- Language: English (United States)
- Name: `Founder Plan`
- Description: `All Pro features plus priority support and priority handling of custom feature requests.`

---

## API による設定（代替方法・実験的）

### 注意
以下の API 呼び出しは教育目的です。Apple のドキュメント更新により、エンドポイント構造が変わる可能性があります。

### 認証トークン生成

```python
import jwt
import time
from datetime import datetime, timezone

private_key = open("~/.appstoreconnect/private_keys/AuthKey_5KT46G9Y29.p8").read()
key_id = "5KT46G9Y29"
issuer_id = "e0d22675-afb3-45f0-a821-06b477f44da0"

now = datetime.now(timezone.utc)
exp = datetime.fromtimestamp(now.timestamp() + 20 * 60, tz=timezone.utc)

payload = {
    "iss": issuer_id,
    "exp": int(exp.timestamp()),
    "aud": "appstoreconnect-v1",
}

token = jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})
```

### 既知の動作エンドポイント

**IAP 一覧取得（成功）**:
```
GET /v1/apps/{APP_ID}/inAppPurchases
Authorization: Bearer {token}
```

**ローカライゼーション取得（失敗）**:
```
GET /v1/inAppPurchases/{IAP_ID}/inAppPurchaseLocalizations
→ 404 Not Found
```

**ローカライゼーション作成（失敗）**:
```
POST /v1/inAppPurchaseLocalizations
Content-Type: application/json

{
  "data": {
    "type": "inAppPurchaseLocalizations",
    "attributes": {
      "locale": "ja",
      "name": "Proプラン",
      "description": "..."
    },
    "relationships": {
      "inAppPurchase": {  // ← このリレーションシップは認識されない
        "data": {
          "type": "inAppPurchases",
          "id": "{IAP_ID}"
        }
      }
    }
  }
}
→ 409 Conflict: 'inAppPurchase' is not a relationship
```

---

## App Store Connect Web UI の代替API

一部の Web UI 機能には、別の内部 API が使用されています:

### Content Delivery API（未公開）

Web UI で メタデータ設定時、以下の形式の内部 API が呼び出されている可能性があります:

```
PATCH /v2/inAppPurchases/{iap_id}/localizations/{locale}
Content-Type: application/json

{
  "name": "...",
  "description": "..."
}
```

ただしこれらの API は公開されていないため、使用できません。

---

## 推奨：Fastlane + deliver

Fastlane の `deliver` アクションは、メタデータを自動で App Store に同期できます:

```bash
cd /Users/yuki/workspace/pon/ios
fastlane deliver --user mail@yukihamada.jp
```

ただし、Fastlane も内部的には Web UI と同じ API を使用しており、IAP メタデータ設定には対応していません。

---

## 結論

**推奨**: Web UI から直接メタデータを設定してください。

理由:
- API による設定が公式サポート外
- 複雑なリレーションシップが必要
- Web UI が最も安定して動作する

所要時間: 約 10-15 分

---

## 参考リンク

- [App Store Connect API Documentation](https://developer.apple.com/documentation/appstoreconnectapi)
- [In-App Purchases API Reference](https://developer.apple.com/documentation/appstoreconnectapi/in_app_purchases)
- [Fastlane Documentation](https://docs.fastlane.tools/)
