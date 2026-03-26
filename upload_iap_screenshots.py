#!/usr/bin/env python3
"""Upload IAP review screenshots to App Store Connect."""

import jwt
import time
import requests
import hashlib
import os
import sys

# Config
KEY_ID = "5KT46G9Y29"
ISSUER_ID = "e0d22675-afb3-45f0-a821-06b477f44da0"
KEY_PATH = os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_5KT46G9Y29.p8")
SCREENSHOT_PATH = "/Users/yuki/workspace/pon/ios/iap_screenshot.png"

# IAP products
FOUNDER_ID = "6761178237"  # NON_CONSUMABLE
PRO_SUB_ID = "6761040880"  # AUTO_RENEWABLE

def generate_token():
    with open(KEY_PATH, "r") as f:
        private_key = f.read()
    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID})

def get_headers(token):
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

def read_screenshot():
    with open(SCREENSHOT_PATH, "rb") as f:
        data = f.read()
    return data

def upload_for_non_consumable(token, iap_id, screenshot_data):
    """Upload review screenshot for non-consumable IAP."""
    print(f"\n=== Uploading screenshot for NON_CONSUMABLE IAP (ID: {iap_id}) ===")
    headers = get_headers(token)
    file_size = len(screenshot_data)
    checksum = hashlib.md5(screenshot_data).hexdigest()

    # Step 1: Create asset reservation
    url = "https://api.appstoreconnect.apple.com/v1/inAppPurchaseAppStoreReviewScreenshots"
    payload = {
        "data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots",
            "attributes": {
                "fileName": "iap_screenshot.png",
                "fileSize": file_size,
            },
            "relationships": {
                "inAppPurchaseV2": {
                    "data": {
                        "type": "inAppPurchases",
                        "id": iap_id,
                    }
                }
            }
        }
    }

    print(f"  Step 1: Creating asset reservation...")
    resp = requests.post(url, json=payload, headers=headers)
    print(f"  Status: {resp.status_code}")
    if resp.status_code not in (200, 201):
        print(f"  Error: {resp.text}")
        return False

    result = resp.json()
    asset_id = result["data"]["id"]
    upload_ops = result["data"]["attributes"].get("uploadOperations", [])
    print(f"  Asset ID: {asset_id}")
    print(f"  Upload operations: {len(upload_ops)}")

    # Step 2: Upload binary data
    print(f"  Step 2: Uploading binary data...")
    for op in upload_ops:
        upload_url = op["url"]
        op_headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
        offset = op["offset"]
        length = op["length"]
        chunk = screenshot_data[offset:offset + length]

        resp = requests.put(upload_url, data=chunk, headers=op_headers)
        print(f"  Upload chunk offset={offset} length={length} -> {resp.status_code}")
        if resp.status_code not in (200, 201):
            print(f"  Error: {resp.text[:500]}")
            return False

    # Step 3: Commit
    print(f"  Step 3: Committing upload...")
    commit_url = f"https://api.appstoreconnect.apple.com/v1/inAppPurchaseAppStoreReviewScreenshots/{asset_id}"
    commit_payload = {
        "data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots",
            "id": asset_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": checksum,
            }
        }
    }
    resp = requests.patch(commit_url, json=commit_payload, headers=headers)
    print(f"  Commit status: {resp.status_code}")
    if resp.status_code not in (200, 201):
        print(f"  Error: {resp.text}")
        return False

    print(f"  Successfully uploaded screenshot for Founder plan!")
    return True

def upload_for_subscription(token, sub_id, screenshot_data):
    """Upload review screenshot for auto-renewable subscription."""
    print(f"\n=== Uploading screenshot for AUTO_RENEWABLE subscription (ID: {sub_id}) ===")
    headers = get_headers(token)
    file_size = len(screenshot_data)
    checksum = hashlib.md5(screenshot_data).hexdigest()

    # Step 1: Create asset reservation
    url = "https://api.appstoreconnect.apple.com/v1/subscriptionAppStoreReviewScreenshots"
    payload = {
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "attributes": {
                "fileName": "iap_screenshot.png",
                "fileSize": file_size,
            },
            "relationships": {
                "subscription": {
                    "data": {
                        "type": "subscriptions",
                        "id": sub_id,
                    }
                }
            }
        }
    }

    print(f"  Step 1: Creating asset reservation...")
    resp = requests.post(url, json=payload, headers=headers)
    print(f"  Status: {resp.status_code}")
    if resp.status_code not in (200, 201):
        print(f"  Error: {resp.text}")
        return False

    result = resp.json()
    asset_id = result["data"]["id"]
    upload_ops = result["data"]["attributes"].get("uploadOperations", [])
    print(f"  Asset ID: {asset_id}")
    print(f"  Upload operations: {len(upload_ops)}")

    # Step 2: Upload binary data
    print(f"  Step 2: Uploading binary data...")
    for op in upload_ops:
        upload_url = op["url"]
        op_headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
        offset = op["offset"]
        length = op["length"]
        chunk = screenshot_data[offset:offset + length]

        resp = requests.put(upload_url, data=chunk, headers=op_headers)
        print(f"  Upload chunk offset={offset} length={length} -> {resp.status_code}")
        if resp.status_code not in (200, 201):
            print(f"  Error: {resp.text[:500]}")
            return False

    # Step 3: Commit
    print(f"  Step 3: Committing upload...")
    commit_url = f"https://api.appstoreconnect.apple.com/v1/subscriptionAppStoreReviewScreenshots/{asset_id}"
    commit_payload = {
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "id": asset_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": checksum,
            }
        }
    }
    resp = requests.patch(commit_url, json=commit_payload, headers=headers)
    print(f"  Commit status: {resp.status_code}")
    if resp.status_code not in (200, 201):
        print(f"  Error: {resp.text}")
        return False

    print(f"  Successfully uploaded screenshot for Pro subscription!")
    return True

def main():
    token = generate_token()
    screenshot_data = read_screenshot()
    print(f"Screenshot size: {len(screenshot_data)} bytes")
    print(f"MD5: {hashlib.md5(screenshot_data).hexdigest()}")

    ok1 = upload_for_non_consumable(token, FOUNDER_ID, screenshot_data)
    ok2 = upload_for_subscription(token, PRO_SUB_ID, screenshot_data)

    if ok1 and ok2:
        print("\n All screenshots uploaded successfully!")
    else:
        print("\n Some uploads failed. Check output above.")
        sys.exit(1)

if __name__ == "__main__":
    main()
