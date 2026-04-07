#!/usr/bin/env python3
"""
ポン IAP セットアップ検証スクリプト
Web UI での操作が完了したかを API で確認
"""

import sys
import jwt
import json
import time
import subprocess
from pathlib import Path

def generate_token():
    """App Store Connect API トークン生成"""
    key_path = Path.home() / '.appstoreconnect/private_keys/AuthKey_5KT46G9Y29.p8'
    
    if not key_path.exists():
        print(f"❌ キーファイルが見つかりません: {key_path}")
        sys.exit(1)
    
    with open(key_path, 'r') as f:
        key = f.read()
    
    now = int(time.time())
    payload = {
        'iss': 'e0d22675-afb3-45f0-a821-06b477f44da0',
        'iat': now,
        'exp': now + 600,
        'aud': 'appstoreconnect-v1'
    }
    
    token = jwt.encode(payload, key, algorithm='ES256', headers={'kid': '5KT46G9Y29'})
    return token

def make_request(method, endpoint, token, data=None):
    """App Store Connect API リクエスト"""
    url = f"https://api.appstoreconnect.apple.com{endpoint}"
    cmd = ['curl', '-s', '-X', method, url, '-H', f'Authorization: Bearer {token}', '-H', 'Content-Type: application/json']
    
    if data:
        cmd += ['-d', json.dumps(data)]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if not result.stdout.strip():
        return None
    
    try:
        return json.loads(result.stdout)
    except:
        return None

def check_iap(token, app_id='6761041004'):
    """IAP 製品確認"""
    resp = make_request('GET', f'/v1/apps/{app_id}/inAppPurchasesV2', token)
    
    if not resp or 'data' not in resp:
        return {}
    
    iaps = {}
    for iap in resp['data']:
        product_id = iap['attributes']['productId']
        iap_id = iap['id']
        state = iap['attributes']['state']
        
        # ローカライゼーション確認
        loc_resp = make_request('GET', f'/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations', token)
        locales = []
        if loc_resp and 'data' in loc_resp:
            locales = [loc['attributes']['locale'] for loc in loc_resp['data']]
        
        # スクリーンショット確認
        ss_resp = make_request('GET', f'/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot', token)
        has_screenshot = ss_resp and 'data' in ss_resp and ss_resp['data'] is not None
        
        iaps[product_id] = {
            'id': iap_id,
            'state': state,
            'locales': locales,
            'has_screenshot': has_screenshot
        }
    
    return iaps

def check_app_store_versions(token, app_id='6761041004'):
    """App Store Version 確認"""
    resp = make_request('GET', f'/v1/apps/{app_id}/appStoreVersions', token)
    
    if not resp or 'data' not in resp:
        return []
    
    versions = []
    for ver in resp['data']:
        version_string = ver['attributes']['versionString']
        state = ver['attributes']['appStoreState']
        versions.append({
            'version': version_string,
            'state': state
        })
    
    return versions

def main():
    print("\n" + "=" * 70)
    print("ポン App Store IAP セットアップ検証")
    print("=" * 70)
    
    try:
        token = generate_token()
        print("\n✅ API トークン生成成功\n")
        
        # IAP 確認
        print("【In-App Purchase 製品】\n")
        iaps = check_iap(token)
        
        required_iaps = {
            'com.enablerdao.pon.pro': 'Proプラン',
            'com.enablerdao.pon.founder': 'ファウンダープラン'
        }
        
        all_iap_ok = True
        for product_id, name in required_iaps.items():
            if product_id in iaps:
                iap = iaps[product_id]
                print(f"✅ {product_id} ({name})")
                print(f"   状態: {iap['state']}")
                print(f"   ローカライゼーション: {', '.join(iap['locales']) if iap['locales'] else '❌ 未設定'}")
                print(f"   スクリーンショット: {'✅ 設定済み' if iap['has_screenshot'] else '❌ 未設定'}")
                
                # チェック
                if iap['state'] not in ['READY_TO_SUBMIT', 'WAITING_FOR_REVIEW', 'IN_REVIEW', 'APPROVED']:
                    all_iap_ok = False
                if not iap['locales']:
                    all_iap_ok = False
                if not iap['has_screenshot']:
                    all_iap_ok = False
            else:
                print(f"❌ {product_id} ({name}) - 未作成")
                all_iap_ok = False
            print()
        
        # App Store Version 確認
        print("【App Store Version】\n")
        versions = check_app_store_versions(token)
        
        all_version_ok = False
        for ver in versions:
            status_emoji = '✅' if ver['state'] in ['IN_REVIEW', 'APPROVED', 'READY_TO_RELEASE'] else '⚠️'
            print(f"{status_emoji} {ver['version']}: {ver['state']}")
            if ver['version'] in ['1.0.1', '1.0.2'] and ver['state'] == 'IN_REVIEW':
                all_version_ok = True
        
        if not versions or all(v['state'] != 'IN_REVIEW' for v in versions):
            all_version_ok = False
        print()
        
        # 最終判定
        print("=" * 70)
        print("\n【最終判定】\n")
        
        if all_iap_ok:
            print("✅ IAP セットアップ: 完了")
        else:
            print("❌ IAP セットアップ: 不完全")
        
        if all_version_ok:
            print("✅ App Store Version: 審査提出完了")
        else:
            print("❌ App Store Version: 未提出または処理中")
        
        print()
        
        if all_iap_ok and all_version_ok:
            print("🎉 全ての設定が完了しました！")
            print("\n次のステップ:")
            print("  1. Activity タブで Version 1.0.1 のステータスを監視")
            print("  2. 24-48 時間後に Approved/Rejected を確認")
            print("  3. Approved なら Manual Release で本番リリース")
            return 0
        else:
            print("⚠️ 以下の項目を確認してください:")
            if not all_iap_ok:
                print("  - Pro プラン IAP の作成・設定")
                print("  - ローカライゼーション (ja, en-US)")
                print("  - スクリーンショット")
            if not all_version_ok:
                print("  - App Store Version 1.0.1 の作成")
                print("  - Build 16 の選択")
                print("  - Review Notes の入力")
                print("  - 「Submit for Review」ボタンのクリック")
            return 1
        
    except Exception as e:
        print(f"\n❌ エラー: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == '__main__':
    sys.exit(main())
