mod db;
mod templates_data;

use axum::{
    extract::{Json, Path, State},
    http::{StatusCode, HeaderMap},
    response::{Html, IntoResponse},
    routing::{get, post},
    Router,
};
use db::Db;
use serde::{Deserialize, Serialize};
use sha2::{Sha256, Digest};
use std::env;
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use tower_http::cors::{CorsLayer, AllowOrigin};

// HTML escape to prevent XSS
fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
     .replace('<', "&lt;")
     .replace('>', "&gt;")
     .replace('"', "&quot;")
     .replace('\'', "&#x27;")
}

// Simple in-memory rate limiter: token -> attempt count in current window
type RateLimiter = Arc<Mutex<HashMap<String, (u32, std::time::Instant)>>>;

fn check_rate_limit(limiter: &RateLimiter, key: &str, max: u32, window_secs: u64) -> bool {
    let mut map = limiter.lock().unwrap();
    let now = std::time::Instant::now();
    let entry = map.entry(key.to_string()).or_insert((0, now));
    if now.duration_since(entry.1).as_secs() > window_secs {
        *entry = (1, now);
        true
    } else if entry.0 < max {
        entry.0 += 1;
        true
    } else {
        false
    }
}

fn sha256_hex(input: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    format!("{:x}", hasher.finalize())
}

fn extract_ip(headers: &HeaderMap) -> String {
    headers.get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.split(',').next().unwrap_or("").trim().to_string())
        .unwrap_or_else(|| "unknown".to_string())
}

fn extract_ua(headers: &HeaderMap) -> String {
    headers.get("user-agent")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("unknown")
        .to_string()
}

#[derive(Clone)]
struct AppState {
    db: Db,
    base_url: String,
    rate_limiter: RateLimiter,
}

// --- Request / Response types ---

#[derive(Deserialize)]
struct CreateContractRequest {
    title: String,
    client_name: String,
    client_email: Option<String>,
    creator_email: Option<String>,
    contract_type: String,
    amount: Option<i64>,
    currency: Option<String>,
    start_date: Option<String>,
    end_date: Option<String>,
    body_text: String,
    creator_name: Option<String>,
    attachments_json: Option<String>,
    // token override only allowed with admin key
    token: Option<String>,
    admin_key: Option<String>,
}

#[derive(Deserialize)]
struct VerifyEmailRequest {
    email: String,
}

#[derive(Serialize)]
struct CreateContractResponse {
    id: String,
    token: String,
    sign_url: String,
}

#[derive(Serialize)]
struct ContractResponse {
    id: String,
    token: String,
    title: String,
    client_name: String,
    client_email: Option<String>,
    contract_type: String,
    amount: i64,
    currency: String,
    start_date: Option<String>,
    end_date: Option<String>,
    body_text: String,
    creator_name: String,
    creator_signature: Option<String>,
    client_signature: Option<String>,
    creator_signed_at: Option<String>,
    client_signed_at: Option<String>,
    status: String,
    created_at: String,
    attachments_json: String,
    sign_url: String,
}

#[derive(Deserialize)]
struct SignRequest {
    signer: String,    // "creator" or "client"
    signature: String, // base64 PNG
}

#[derive(Serialize)]
struct SignResponse {
    success: bool,
    status: String,
    message: String,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

// --- Handlers ---

async fn health() -> &'static str {
    "ok"
}

async fn privacy_page() -> Html<&'static str> {
    Html(r#"<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>プライバシーポリシー - Pon</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Hiragino Sans', sans-serif; max-width: 680px; margin: 0 auto; padding: 24px 16px 60px; background: #0F0F1A; color: #e0e0e0; line-height: 1.8; }
h1 { background: linear-gradient(135deg, #7B2FBE, #4CC9F0); -webkit-background-clip: text; -webkit-text-fill-color: transparent; font-size: 28px; margin-bottom: 8px; }
h2 { color: #fff; font-size: 18px; margin-top: 32px; }
p, li { color: #ccc; font-size: 14px; }
a { color: #7B2FBE; }
.updated { color: #888; font-size: 13px; margin-bottom: 32px; }
</style>
</head>
<body>
<h1>Pon プライバシーポリシー</h1>
<div class="updated">最終更新: 2026年3月26日</div>

<p>Enabler DAO（以下「当社」）は、電子契約・署名サービス「Pon」（以下「本サービス」）におけるユーザーの個人情報の取り扱いについて、以下のとおりプライバシーポリシーを定めます。</p>

<h2>1. 収集する情報</h2>
<p>本サービスでは、以下の情報を収集することがあります。</p>
<ul>
  <li><strong>氏名・メールアドレス</strong>: 契約書作成時および署名時に入力された情報</li>
  <li><strong>電子署名データ</strong>: 手書き署名の画像データ（PNG形式）</li>
  <li><strong>IPアドレス・User-Agent</strong>: 不正利用防止のための監査ログ</li>
  <li><strong>契約書の内容</strong>: ユーザーが入力した契約書テキスト</li>
</ul>

<h2>2. 情報の利用目的</h2>
<ul>
  <li>電子契約・署名サービスの提供</li>
  <li>契約の真正性・改ざん検知のための記録</li>
  <li>不正利用の防止</li>
  <li>サービスの改善</li>
</ul>

<h2>3. 情報の第三者提供</h2>
<p>当社は、法令に基づく場合を除き、ユーザーの同意なく個人情報を第三者に提供しません。</p>

<h2>4. データの保管</h2>
<p>契約データはFly.io（東京リージョン）のサーバーに暗号化通信（HTTPS）を用いて保管されます。iOSアプリのデータはデバイス内のSwiftDataにローカル保管されます。</p>

<h2>5. データの削除</h2>
<p>データの削除を希望される場合は、下記の連絡先までお問い合わせください。</p>

<h2>6. セキュリティ</h2>
<ul>
  <li>全通信はHTTPS（TLS 1.2以上）で暗号化</li>
  <li>署名URLはランダムなUUIDトークンで保護</li>
  <li>文書ハッシュ（SHA-256）による改ざん検知</li>
  <li>アクセスログの記録（IP・タイムスタンプ・User-Agent）</li>
</ul>

<h2>7. お問い合わせ</h2>
<p>個人情報の取り扱いに関するお問い合わせは、以下までご連絡ください。<br>
メール: <a href="mailto:info@enablerdao.com">info@enablerdao.com</a></p>

<h2>8. ポリシーの変更</h2>
<p>本ポリシーは予告なく変更することがあります。重要な変更がある場合はアプリ内でお知らせします。</p>
</body>
</html>"#)
}

async fn terms_page() -> Html<&'static str> {
    Html(r#"<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>利用規約 - Pon</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Hiragino Sans', sans-serif; max-width: 680px; margin: 0 auto; padding: 24px 16px 60px; background: #0F0F1A; color: #e0e0e0; line-height: 1.8; }
h1 { background: linear-gradient(135deg, #7B2FBE, #4CC9F0); -webkit-background-clip: text; -webkit-text-fill-color: transparent; font-size: 28px; margin-bottom: 8px; }
h2 { color: #fff; font-size: 18px; margin-top: 32px; }
p, li { color: #ccc; font-size: 14px; }
a { color: #7B2FBE; }
.updated { color: #888; font-size: 13px; margin-bottom: 32px; }
</style>
</head>
<body>
<h1>Pon 利用規約</h1>
<div class="updated">最終更新: 2026年3月26日</div>

<h2>第1条（サービスの目的）</h2>
<p>本サービスは、電子契約書の作成・署名・管理を支援するツールです。電子署名法に基づく電子署名として利用することができます。</p>

<h2>第2条（利用条件）</h2>
<ul>
  <li>本サービスは18歳以上の方が利用できます</li>
  <li>違法・不正な目的での使用は禁止します</li>
  <li>他者を欺く目的での署名は禁止します</li>
</ul>

<h2>第3条（法的効力）</h2>
<p>本サービスで作成・署名した電子契約書は、電子署名法および民法の規定に基づき法的効力を持ちます。ただし、法的効力の最終的な判断は当事者および専門家（弁護士等）の確認をお勧めします。</p>

<h2>第4条（免責事項）</h2>
<p>当社は、本サービスを利用して締結された契約の内容・効力・履行について一切の責任を負いません。契約内容の適法性・有効性についてはユーザーご自身の責任でご確認ください。</p>

<h2>第5条（サービスの変更・停止）</h2>
<p>当社は、予告なくサービスの内容を変更または停止する場合があります。</p>

<h2>第6条（準拠法・管轄）</h2>
<p>本規約は日本法に準拠し、東京地方裁判所を専属的合意管轄裁判所とします。</p>

<h2>お問い合わせ</h2>
<p>メール: <a href="mailto:info@enablerdao.com">info@enablerdao.com</a></p>
</body>
</html>"#)
}

async fn landing_page(State(state): State<AppState>) -> Html<String> {
    let templates = templates_data::get_templates();
    let template_options: String = templates.iter().map(|t| {
        format!(r#"<option value="{}" data-body="{}">{}</option>"#,
            t.id, t.body.replace('"', "&quot;").replace('\n', "\\n"), t.name)
    }).collect::<Vec<_>>().join("\n");

    let db = state.db.lock().unwrap();
    let count: i64 = db.query_row("SELECT COUNT(*) FROM contracts", [], |r| r.get(0)).unwrap_or(0);
    let signed: i64 = db.query_row("SELECT COUNT(*) FROM contracts WHERE status='completed'", [], |r| r.get(0)).unwrap_or(0);
    drop(db);

    Html(format!(r##"<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Pon - 電子契約サービス</title>
<meta name="description" content="無料で使える電子契約・署名サービス。契約書を作成して、URLを共有するだけ。">
<meta property="og:title" content="Pon - 電子契約サービス">
<meta property="og:description" content="無料で使える電子契約・署名サービス。契約書を作成して、URLを共有するだけ。">
<meta property="og:type" content="website">
<meta property="og:url" content="https://pon.enablerdao.com">
<meta property="og:image" content="https://pon.enablerdao.com/ogp.png">
<meta property="og:site_name" content="Pon - 電子契約サービス">
<meta property="og:locale" content="ja_JP">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="Pon - 電子契約サービス">
<meta name="twitter:description" content="無料で使える電子契約・署名サービス。契約書を作成して、URLを共有するだけ。">
<meta name="twitter:image" content="https://pon.enablerdao.com/ogp.png">
<link rel="icon" type="image/png" href="/favicon.png">
<style>
*,*::before,*::after {{ box-sizing:border-box; margin:0; padding:0; }}
body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Hiragino Sans', sans-serif;
    background: #0F0F1A;
    color: #e0e0e0;
    min-height: 100vh;
}}
.container {{ max-width: 720px; margin: 0 auto; padding: 20px 16px 40px; }}
.hero {{
    text-align: center;
    padding: 48px 0 32px;
}}
.logo {{
    font-size: 48px;
    font-weight: 800;
    background: linear-gradient(135deg, #7B2FBE, #4CC9F0);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    letter-spacing: 3px;
}}
.tagline {{
    font-size: 18px;
    color: #aaa;
    margin-top: 8px;
}}
.stats {{
    display: flex;
    justify-content: center;
    gap: 32px;
    margin-top: 24px;
}}
.stat {{ text-align: center; }}
.stat-num {{
    font-size: 28px;
    font-weight: 700;
    background: linear-gradient(135deg, #7B2FBE, #4CC9F0);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
}}
.stat-label {{ font-size: 12px; color: #888; margin-top: 2px; }}
.card {{
    background: #16213E;
    border-radius: 16px;
    padding: 24px;
    margin-bottom: 16px;
    border: 1px solid rgba(123,47,190,0.2);
}}
.card-title {{
    font-size: 18px;
    font-weight: 600;
    margin-bottom: 16px;
    color: #fff;
}}
.form-group {{
    margin-bottom: 16px;
}}
.form-group label {{
    display: block;
    font-size: 13px;
    color: #aaa;
    margin-bottom: 6px;
    font-weight: 500;
}}
.form-group input, .form-group select, .form-group textarea {{
    width: 100%;
    padding: 12px 14px;
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 10px;
    color: #e0e0e0;
    font-size: 15px;
    font-family: inherit;
    outline: none;
    transition: border-color 0.2s;
}}
.form-group input:focus, .form-group select:focus, .form-group textarea:focus {{
    border-color: #7B2FBE;
}}
.form-group textarea {{
    min-height: 200px;
    resize: vertical;
    line-height: 1.7;
}}
.form-row {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
}}
.btn {{
    padding: 14px 24px;
    border: none;
    border-radius: 12px;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    text-decoration: none;
    display: inline-block;
    text-align: center;
}}
.btn-primary {{
    width: 100%;
    background: linear-gradient(135deg, #7B2FBE, #5B1F9E);
    color: #fff;
    font-size: 17px;
    padding: 16px;
}}
.btn-primary:hover {{ transform: translateY(-1px); box-shadow: 0 4px 20px rgba(123,47,190,0.4); }}
.btn-primary:disabled {{ opacity: 0.5; cursor: not-allowed; transform: none; box-shadow: none; }}
.btn-outline {{
    background: transparent;
    color: #7B2FBE;
    border: 1px solid #7B2FBE;
    padding: 12px 20px;
    font-size: 14px;
}}
.btn-outline:hover {{ background: rgba(123,47,190,0.1); }}
.nav-links {{
    display: flex;
    justify-content: center;
    gap: 16px;
    margin-top: 16px;
}}
.features {{
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
    margin-bottom: 24px;
}}
.feature {{
    background: rgba(123,47,190,0.08);
    border-radius: 12px;
    padding: 16px;
    text-align: center;
}}
.feature-icon {{ font-size: 28px; margin-bottom: 6px; }}
.feature-text {{ font-size: 12px; color: #aaa; }}
.footer {{
    text-align: center;
    padding: 24px 0;
    font-size: 12px;
    color: #555;
}}
.loading {{
    display: none;
    align-items: center;
    justify-content: center;
    gap: 12px;
    padding: 16px;
    color: #4CC9F0;
}}
.spinner {{
    width: 24px; height: 24px;
    border: 3px solid rgba(76,201,240,0.2);
    border-top-color: #4CC9F0;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
}}
@keyframes spin {{ to {{ transform: rotate(360deg); }} }}
@media (max-width: 480px) {{
    .form-row {{ grid-template-columns: 1fr; }}
    .features {{ grid-template-columns: 1fr; }}
    .hero {{ padding: 32px 0 24px; }}
    .logo {{ font-size: 36px; }}
}}
</style>
</head>
<body>
<div class="container">
    <div class="hero">
        <div class="logo">Pon</div>
        <div class="tagline">決まった、ポン。電子契約サービス</div>
        <div class="stats">
            <div class="stat">
                <div class="stat-num">{count}</div>
                <div class="stat-label">契約書作成</div>
            </div>
            <div class="stat">
                <div class="stat-num">{signed}</div>
                <div class="stat-label">署名完了</div>
            </div>
        </div>
        <div class="nav-links">
            <a href="/dashboard" class="btn btn-outline">契約一覧</a>
        </div>
    </div>

    <div class="features">
        <div class="feature">
            <div class="feature-icon">&#9997;</div>
            <div class="feature-text">手書き電子署名</div>
        </div>
        <div class="feature">
            <div class="feature-icon">&#128279;</div>
            <div class="feature-text">URLで共有</div>
        </div>
        <div class="feature">
            <div class="feature-icon">&#128274;</div>
            <div class="feature-text">改ざん検知</div>
        </div>
    </div>

    <div class="card">
        <div class="card-title">新しい契約書を作成</div>
        <form id="create-form">
            <div class="form-row">
                <div class="form-group">
                    <label>契約種別</label>
                    <select id="f-type" required>
                        {template_options}
                    </select>
                </div>
                <div class="form-group">
                    <label>契約タイトル</label>
                    <input type="text" id="f-title" placeholder="例: システム開発業務委託契約" required>
                </div>
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label>甲（作成者）名</label>
                    <input type="text" id="f-creator" placeholder="例: 山田太郎" required>
                </div>
                <div class="form-group">
                    <label>乙（署名者）名</label>
                    <input type="text" id="f-client" placeholder="例: 佐藤花子" required>
                </div>
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label>乙のメールアドレス（任意）</label>
                    <input type="email" id="f-email" placeholder="例: client@example.com">
                </div>
                <div class="form-group">
                    <label>金額（円）</label>
                    <input type="number" id="f-amount" placeholder="例: 500000" min="0">
                </div>
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label>開始日</label>
                    <input type="date" id="f-start">
                </div>
                <div class="form-group">
                    <label>終了日</label>
                    <input type="date" id="f-end">
                </div>
            </div>
            <div class="form-group">
                <label>契約本文</label>
                <textarea id="f-body" placeholder="テンプレートを選択すると自動入力されます" required></textarea>
            </div>
            <button type="submit" class="btn btn-primary" id="btn-create">契約書を作成して署名へ</button>
            <div class="loading" id="creating">
                <div class="spinner"></div>
                <span>作成中...</span>
            </div>
        </form>
    </div>

    <div style="display:flex;align-items:center;justify-content:space-between;background:rgba(123,47,190,0.1);border:1px solid rgba(123,47,190,0.25);border-radius:14px;padding:14px 18px;margin-bottom:16px;">
        <div>
            <div style="font-size:14px;font-weight:700;color:#fff;">Ponアプリ（無料）</div>
            <div style="font-size:11px;color:#aaa;margin-top:2px;">iPhoneで契約書を作成・管理・署名</div>
        </div>
        <a href="https://testflight.apple.com/join/XyZdmPVt" target="_blank"
           style="display:flex;align-items:center;gap:6px;background:#7B2FBE;color:#fff;text-decoration:none;padding:9px 16px;border-radius:10px;font-size:13px;font-weight:600;white-space:nowrap;">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="white"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
            App Store
        </a>
    </div>
    <div class="footer">
        Powered by Pon &mdash; Secure Digital Contracts
    </div>
</div>
<script>
(function() {{
    const typeSelect = document.getElementById('f-type');
    const bodyText = document.getElementById('f-body');
    const titleInput = document.getElementById('f-title');

    function fillTemplate() {{
        const opt = typeSelect.options[typeSelect.selectedIndex];
        const body = opt.dataset.body || '';
        bodyText.value = body.replace(/\\n/g, '\n');
        if (!titleInput.value) {{
            titleInput.value = opt.textContent;
        }}
    }}
    typeSelect.addEventListener('change', fillTemplate);
    fillTemplate();

    // Set default dates
    const today = new Date();
    document.getElementById('f-start').value = today.toISOString().split('T')[0];
    const oneYear = new Date(today);
    oneYear.setFullYear(oneYear.getFullYear() + 1);
    document.getElementById('f-end').value = oneYear.toISOString().split('T')[0];

    document.getElementById('create-form').addEventListener('submit', async function(e) {{
        e.preventDefault();
        const btn = document.getElementById('btn-create');
        const loading = document.getElementById('creating');
        btn.disabled = true;
        loading.style.display = 'flex';

        // Replace placeholders
        let body = bodyText.value;
        const creator = document.getElementById('f-creator').value;
        const client = document.getElementById('f-client').value;
        const amount = document.getElementById('f-amount').value || '0';
        const start = document.getElementById('f-start').value;
        const end = document.getElementById('f-end').value;
        body = body.replace(/\{{creator_name\}}/g, creator)
                   .replace(/\{{client_name\}}/g, client)
                   .replace(/\{{amount\}}/g, Number(amount).toLocaleString())
                   .replace(/\{{start_date\}}/g, start)
                   .replace(/\{{end_date\}}/g, end)
                   .replace(/\{{description\}}/g, document.getElementById('f-title').value);

        try {{
            const res = await fetch('/api/contracts', {{
                method: 'POST',
                headers: {{ 'Content-Type': 'application/json' }},
                body: JSON.stringify({{
                    title: document.getElementById('f-title').value,
                    client_name: client,
                    client_email: document.getElementById('f-email').value || null,
                    contract_type: typeSelect.value,
                    amount: parseInt(amount) || 0,
                    currency: 'JPY',
                    start_date: start,
                    end_date: end,
                    body_text: body,
                    creator_name: creator,
                }})
            }});
            const data = await res.json();
            if (data.sign_url) {{
                window.location.href = data.sign_url;
            }} else {{
                alert('エラー: ' + (data.error || '作成に失敗しました'));
                btn.disabled = false;
                loading.style.display = 'none';
            }}
        }} catch(err) {{
            alert('通信エラー: ' + err.message);
            btn.disabled = false;
            loading.style.display = 'none';
        }}
    }});
}})();
</script>
</body>
</html>"##))
}

async fn dashboard_page(
    State(state): State<AppState>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Html<String>, (StatusCode, Html<String>)> {
    let secret = match std::env::var("DASHBOARD_SECRET") {
        Ok(s) if !s.is_empty() => s,
        _ => return Err((StatusCode::FORBIDDEN, Html("<h1>Dashboard disabled</h1>".to_string()))),
    };
    if params.get("secret").map(|s| s.as_str()) != Some(secret.as_str()) {
        return Err((StatusCode::UNAUTHORIZED, Html("<h1>401 Unauthorized</h1><p><a href='/'>トップへ</a></p>".to_string())));
    }
    Ok(dashboard_page_inner(state).await)
}

async fn dashboard_page_inner(state: AppState) -> Html<String> {
    let db = state.db.lock().unwrap();
    let mut stmt = db.prepare(
        "SELECT id, token, title, client_name, contract_type, amount, currency, status, created_at, creator_name FROM contracts ORDER BY created_at DESC LIMIT 100"
    ).unwrap();
    let contracts: Vec<(String,String,String,String,String,i64,String,String,String,String)> = stmt.query_map([], |row| {
        Ok((
            row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?,
            row.get(4)?, row.get(5)?, row.get(6)?, row.get(7)?,
            row.get(8)?, row.get(9)?,
        ))
    }).unwrap().filter_map(|r| r.ok()).collect();
    drop(stmt);
    drop(db);

    let rows_html: String = if contracts.is_empty() {
        r#"<div style="text-align:center;padding:48px 16px;color:#888;">
            <div style="font-size:48px;margin-bottom:16px;">&#128196;</div>
            <p>まだ契約書がありません</p>
            <a href="/" class="btn btn-primary" style="margin-top:16px;display:inline-block;width:auto;padding:12px 32px;">最初の契約書を作成</a>
        </div>"#.to_string()
    } else {
        contracts.iter().map(|(_id, token, title, client, _ctype, amount, currency, status, created, creator)| {
            let badge = match status.as_str() {
                "completed" => r#"<span class="badge badge-complete">完了</span>"#,
                "creator_signed" => r#"<span class="badge badge-partial">甲署名済</span>"#,
                _ => r#"<span class="badge badge-pending">署名待ち</span>"#,
            };
            let amt = format_amount(*amount, currency);
            let date = created.split('T').next().unwrap_or(created);
            let title_e = html_escape(title);
            let creator_e = html_escape(creator);
            let client_e = html_escape(client);
            format!(r#"<a href="/sign/{token}" class="contract-row">
                <div class="cr-main">
                    <div class="cr-title">{title_e}</div>
                    <div class="cr-meta">{creator_e} ⇄ {client_e} | {amt}</div>
                </div>
                <div class="cr-right">
                    {badge}
                    <div class="cr-date">{date}</div>
                </div>
            </a>"#)
        }).collect()
    };

    Html(format!(r##"<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>契約一覧 - Pon</title>
<style>
*,*::before,*::after {{ box-sizing:border-box; margin:0; padding:0; }}
body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Hiragino Sans', sans-serif;
    background: #0F0F1A;
    color: #e0e0e0;
    min-height: 100vh;
}}
.container {{ max-width: 720px; margin: 0 auto; padding: 20px 16px 40px; }}
.header {{
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 0 24px;
}}
.logo {{
    font-size: 28px;
    font-weight: 700;
    background: linear-gradient(135deg, #7B2FBE, #4CC9F0);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    text-decoration: none;
}}
.btn {{
    padding: 10px 20px;
    border: none;
    border-radius: 10px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    text-decoration: none;
    color: #fff;
    background: linear-gradient(135deg, #7B2FBE, #5B1F9E);
    transition: all 0.2s;
}}
.btn:hover {{ transform: translateY(-1px); box-shadow: 0 4px 20px rgba(123,47,190,0.4); }}
.btn-primary {{ width: 100%; background: linear-gradient(135deg, #7B2FBE, #5B1F9E); color: #fff; font-size: 17px; padding: 16px; border-radius: 12px; }}
.card {{
    background: #16213E;
    border-radius: 16px;
    padding: 4px;
    border: 1px solid rgba(123,47,190,0.2);
}}
.contract-row {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px;
    border-bottom: 1px solid rgba(255,255,255,0.04);
    text-decoration: none;
    color: inherit;
    transition: background 0.15s;
}}
.contract-row:last-child {{ border-bottom: none; }}
.contract-row:hover {{ background: rgba(123,47,190,0.06); }}
.cr-title {{ font-size: 15px; font-weight: 600; color: #fff; }}
.cr-meta {{ font-size: 12px; color: #888; margin-top: 4px; }}
.cr-right {{ text-align: right; flex-shrink: 0; }}
.cr-date {{ font-size: 11px; color: #666; margin-top: 4px; }}
.badge {{
    display: inline-block;
    padding: 3px 10px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 600;
}}
.badge-pending {{ background: rgba(255,193,7,0.15); color: #FFC107; }}
.badge-partial {{ background: rgba(76,201,240,0.15); color: #4CC9F0; }}
.badge-complete {{ background: rgba(76,175,80,0.15); color: #4CAF50; }}
.footer {{
    text-align: center;
    padding: 24px 0;
    font-size: 12px;
    color: #555;
}}
</style>
</head>
<body>
<div class="container">
    <div class="header">
        <a href="/" class="logo">Pon</a>
        <a href="/" class="btn">+ 新規作成</a>
    </div>
    <div class="card">
        {rows_html}
    </div>
    <div class="footer">
        Powered by Pon &mdash; Secure Digital Contracts
    </div>
</div>
</body>
</html>"##))
}

async fn create_contract(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<CreateContractRequest>,
) -> Result<(StatusCode, Json<CreateContractResponse>), (StatusCode, Json<ErrorResponse>)> {
    // Rate limit: 30 contracts per IP per hour
    let ip = extract_ip(&headers);
    if !check_rate_limit(&state.rate_limiter, &format!("create:{}", ip), 30, 3600) {
        return Err((StatusCode::TOO_MANY_REQUESTS, Json(ErrorResponse { error: "Rate limit exceeded".to_string() })));
    }
    let id = uuid::Uuid::new_v4().to_string();
    // Token handling:
    // - With valid admin_key: any token string allowed
    // - Without admin_key: only valid UUID-format tokens accepted (app-generated)
    // - UNIQUE constraint prevents overwriting existing contracts
    let admin_secret = env::var("ADMIN_KEY").unwrap_or_else(|_| "".to_string());
    let token = if let Some(tok) = &req.token {
        if let (Some(key),) = (&req.admin_key,) {
            if !admin_secret.is_empty() && key == &admin_secret {
                tok.clone()
            } else {
                uuid::Uuid::new_v4().to_string()
            }
        } else if uuid::Uuid::parse_str(tok).is_ok() {
            // App-generated UUID token: allow without admin key
            tok.clone()
        } else {
            uuid::Uuid::new_v4().to_string()
        }
    } else {
        uuid::Uuid::new_v4().to_string()
    };
    let creator_name = req.creator_name.unwrap_or_else(|| "Yuki Hamada".to_string());
    let amount = req.amount.unwrap_or(0);
    let currency = req.currency.unwrap_or_else(|| "JPY".to_string());
    let attachments = req.attachments_json.unwrap_or_else(|| "[]".to_string());
    let document_hash = sha256_hex(&req.body_text);
    let ip = extract_ip(&headers);
    let ua = extract_ua(&headers);

    let db = state.db.lock().unwrap();
    let insert_result = db.execute(
        "INSERT INTO contracts (id, token, title, client_name, client_email, creator_email, contract_type, amount, currency, start_date, end_date, body_text, creator_name, attachments_json, document_hash) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)",
        rusqlite::params![id, token, req.title, req.client_name, req.client_email, req.creator_email, req.contract_type, amount, currency, req.start_date, req.end_date, req.body_text, creator_name, attachments, document_hash],
    );
    // If token already exists (UNIQUE constraint), return 409 with existing sign URL
    if let Err(ref e) = insert_result {
        if e.to_string().contains("UNIQUE") {
            let sign_url = format!("{}/sign/{}", state.base_url, token);
            return Ok((StatusCode::CONFLICT, Json(CreateContractResponse { id: token.clone(), token, sign_url })));
        }
        eprintln!("[ERROR] create_contract DB: {}", e);
        return Err((StatusCode::INTERNAL_SERVER_ERROR, Json(ErrorResponse { error: "Internal server error".to_string() })));
    }

    db::append_audit_log(&db, &id, "contract_created", &ip, &ua, &format!("document_hash: {}", document_hash));

    let sign_url = format!("{}/sign/{}", state.base_url, token);

    Ok((
        StatusCode::CREATED,
        Json(CreateContractResponse {
            id,
            token,
            sign_url,
        }),
    ))
}

async fn get_contract_by_token(
    State(state): State<AppState>,
    Path(token): Path<String>,
) -> Result<Json<ContractResponse>, (StatusCode, Json<ErrorResponse>)> {
    let db = state.db.lock().unwrap();
    let mut stmt = db
        .prepare("SELECT id, token, title, client_name, client_email, contract_type, amount, currency, start_date, end_date, body_text, creator_name, creator_signature, client_signature, creator_signed_at, client_signed_at, status, created_at, attachments_json FROM contracts WHERE token = ?1")
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ErrorResponse { error: e.to_string() })))?;
    let contract = stmt
        .query_row(rusqlite::params![token], |row| {
            let tok: String = row.get(1)?;
            let sign_url = format!("{}/sign/{}", "https://pon.enablerdao.com", tok);
            Ok(ContractResponse {
                id: row.get(0)?, token: tok, title: row.get(2)?, client_name: row.get(3)?,
                client_email: row.get(4)?, contract_type: row.get(5)?, amount: row.get(6)?,
                currency: row.get(7)?, start_date: row.get(8)?, end_date: row.get(9)?,
                body_text: row.get(10)?, creator_name: row.get(11)?,
                creator_signature: row.get(12)?, client_signature: row.get(13)?,
                creator_signed_at: row.get(14)?, client_signed_at: row.get(15)?,
                status: row.get(16)?, created_at: row.get(17)?, attachments_json: row.get(18)?,
                sign_url,
            })
        })
        .map_err(|_| (StatusCode::NOT_FOUND, Json(ErrorResponse { error: "Contract not found".to_string() })))?;
    Ok(Json(contract))
}

async fn get_contract(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<ContractResponse>, (StatusCode, Json<ErrorResponse>)> {
    let db = state.db.lock().unwrap();
    let mut stmt = db
        .prepare("SELECT id, token, title, client_name, client_email, contract_type, amount, currency, start_date, end_date, body_text, creator_name, creator_signature, client_signature, creator_signed_at, client_signed_at, status, created_at, attachments_json FROM contracts WHERE id = ?1")
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ErrorResponse { error: e.to_string() })))?;

    let contract = stmt
        .query_row(rusqlite::params![id], |row| {
            let _token: String = row.get(1)?;
            Ok(ContractResponse {
                id: row.get(0)?,
                token: "***".to_string(), // hidden for security
                title: row.get(2)?,
                client_name: row.get(3)?,
                client_email: row.get(4)?,
                contract_type: row.get(5)?,
                amount: row.get(6)?,
                currency: row.get(7)?,
                start_date: row.get(8)?,
                end_date: row.get(9)?,
                body_text: row.get(10)?,
                creator_name: row.get(11)?,
                creator_signature: row.get(12)?,
                client_signature: row.get(13)?,
                creator_signed_at: row.get(14)?,
                client_signed_at: row.get(15)?,
                status: row.get(16)?,
                created_at: row.get(17)?,
                attachments_json: row.get(18)?,
                sign_url: "***".to_string(), // hidden for security
            })
        })
        .map_err(|_| {
            (
                StatusCode::NOT_FOUND,
                Json(ErrorResponse {
                    error: "Contract not found".to_string(),
                }),
            )
        })?;

    Ok(Json(contract))
}

async fn sign_page(
    State(state): State<AppState>,
    Path(token): Path<String>,
) -> Result<Html<String>, (StatusCode, Html<String>)> {
    let db = state.db.lock().unwrap();
    let mut stmt = db
        .prepare("SELECT id, title, client_name, contract_type, amount, currency, start_date, end_date, body_text, creator_name, creator_signature, client_signature, creator_signed_at, client_signed_at, status, token FROM contracts WHERE token = ?1")
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Html("DB error".to_string())))?;

    let result = stmt.query_row(rusqlite::params![token], |row| {
        Ok((
            row.get::<_, String>(0)?,    // id
            row.get::<_, String>(1)?,    // title
            row.get::<_, String>(2)?,    // client_name
            row.get::<_, String>(3)?,    // contract_type
            row.get::<_, i64>(4)?,       // amount
            row.get::<_, String>(5)?,    // currency
            row.get::<_, Option<String>>(6)?, // start_date
            row.get::<_, Option<String>>(7)?, // end_date
            row.get::<_, String>(8)?,    // body_text
            row.get::<_, String>(9)?,    // creator_name
            row.get::<_, Option<String>>(10)?, // creator_signature
            row.get::<_, Option<String>>(11)?, // client_signature
            row.get::<_, Option<String>>(12)?, // creator_signed_at
            row.get::<_, Option<String>>(13)?, // client_signed_at
            row.get::<_, String>(14)?,   // status
            row.get::<_, String>(15)?,   // token
        ))
    });

    let (id, title, client_name, contract_type, amount, currency, start_date, end_date, body_text, creator_name, creator_sig, client_sig, creator_signed_at, client_signed_at, status, tok) = result.map_err(|_| {
        (StatusCode::NOT_FOUND, Html(r#"<!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>契約書が見つかりません - Pon</title>
<meta property="og:title" content="Pon - 電子契約サービス"><meta property="og:description" content="無料で使える電子契約・署名サービス"><meta property="og:image" content="https://pon.enablerdao.com/ogp.png"><meta name="twitter:card" content="summary_large_image">
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:-apple-system,sans-serif;background:#0F0F1A;color:#e0e0e0;min-height:100vh;display:flex;align-items:center;justify-content:center}.c{text-align:center;padding:40px}h1{font-size:24px;margin-bottom:16px}p{color:#888;margin-bottom:24px;font-size:15px}.btn{display:inline-block;padding:14px 28px;background:linear-gradient(135deg,#7B2FBE,#5B1F9E);color:#fff;text-decoration:none;border-radius:12px;font-weight:600;margin:8px}.btn-s{background:rgba(255,255,255,0.08);color:#ccc}</style></head>
<body><div class="c"><h1>契約書が見つかりません</h1><p>このURLの契約書は存在しないか、削除されています。</p><a href="/" class="btn">新しい契約書を作成</a><br><a href="https://testflight.apple.com/join/XyZdmPVt" class="btn btn-s">Ponアプリをダウンロード</a></div></body></html>"#.to_string()))
    })?;

    let type_label = match contract_type.as_str() {
        "nda" => "秘密保持契約書",
        "development" => "業務委託契約書",
        "maintenance" => "保守契約書",
        "consulting" => "コンサルティング契約書",
        "sales" => "売買契約書",
        _ => &contract_type,
    };

    let both_signed = status == "completed";
    let creator_signed = creator_sig.is_some();
    let client_signed = client_sig.is_some();

    let amount_display = format_amount(amount, &currency);
    let start_display = html_escape(&start_date.unwrap_or_default());
    let end_display = html_escape(&end_date.unwrap_or_default());
    let body_html = html_escape(&body_text).replace('\n', "<br>");
    let title = html_escape(&title);
    let client_name = html_escape(&client_name);
    let creator_name = html_escape(&creator_name);

    let html = render_sign_page(
        &id, &tok, &title, &client_name, type_label, &amount_display,
        &start_display, &end_display, &body_html, &creator_name,
        creator_signed, client_signed, both_signed,
        creator_sig.as_deref(), client_sig.as_deref(),
        creator_signed_at.as_deref(), client_signed_at.as_deref(),
        &status,
    );

    Ok(Html(html))
}

fn format_amount(amount: i64, currency: &str) -> String {
    match currency {
        "JPY" => format!("{}{}", "¥", format_number(amount)),
        "USD" => format!("${}", format_number(amount)),
        _ => format!("{} {}", format_number(amount), currency),
    }
}

fn format_number(n: i64) -> String {
    let s = n.to_string();
    let mut result = String::new();
    for (i, c) in s.chars().rev().enumerate() {
        if i > 0 && i % 3 == 0 {
            result.push(',');
        }
        result.push(c);
    }
    result.chars().rev().collect()
}

async fn submit_signature(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(token): Path<String>,
    Json(req): Json<SignRequest>,
) -> Result<Json<SignResponse>, (StatusCode, Json<ErrorResponse>)> {
    if req.signer != "creator" && req.signer != "client" {
        return Err((StatusCode::BAD_REQUEST, Json(ErrorResponse { error: "signer must be 'creator' or 'client'".to_string() })));
    }
    // Rate limit: max 10 sign attempts per token per hour
    let ip = extract_ip(&headers);
    let rate_key = format!("sign:{}:{}", token, ip);
    if !check_rate_limit(&state.rate_limiter, &rate_key, 10, 3600) {
        return Err((StatusCode::TOO_MANY_REQUESTS, Json(ErrorResponse { error: "試行回数が多すぎます。しばらく待ってから再試行してください。".to_string() })));
    }
    // Signature size limit: 2MB base64
    if req.signature.len() > 2 * 1024 * 1024 {
        return Err((StatusCode::PAYLOAD_TOO_LARGE, Json(ErrorResponse { error: "署名データが大きすぎます".to_string() })));
    }
    // Basic signature format validation
    if !req.signature.starts_with("data:image/") && !req.signature.starts_with("data:application/") {
        return Err((StatusCode::BAD_REQUEST, Json(ErrorResponse { error: "無効な署名フォーマットです".to_string() })));
    }

    let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
    let db = state.db.lock().unwrap();

    // Check contract exists
    let status: String = db
        .query_row(
            "SELECT status FROM contracts WHERE token = ?1",
            rusqlite::params![token],
            |row| row.get(0),
        )
        .map_err(|_| {
            (
                StatusCode::NOT_FOUND,
                Json(ErrorResponse {
                    error: "Contract not found".to_string(),
                }),
            )
        })?;

    if status == "completed" {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Contract already fully signed".to_string(),
            }),
        ));
    }

    // Prevent overwriting an existing signature
    let existing_sig: Option<String> = if req.signer == "creator" {
        db.query_row("SELECT creator_signature FROM contracts WHERE token = ?1", rusqlite::params![token], |r| r.get(0)).ok().flatten()
    } else {
        db.query_row("SELECT client_signature FROM contracts WHERE token = ?1", rusqlite::params![token], |r| r.get(0)).ok().flatten()
    };
    if existing_sig.is_some() {
        return Err((
            StatusCode::CONFLICT,
            Json(ErrorResponse {
                error: "This party has already signed".to_string(),
            }),
        ));
    }

    let ip = extract_ip(&headers);
    let ua = extract_ua(&headers);

    // Use static SQL queries to prevent column injection
    let query = if req.signer == "creator" {
        "UPDATE contracts SET creator_signature = ?1, creator_signed_at = ?2, creator_ip = ?3, creator_user_agent = ?4 WHERE token = ?5"
    } else {
        "UPDATE contracts SET client_signature = ?1, client_signed_at = ?2, client_ip = ?3, client_user_agent = ?4 WHERE token = ?5"
    };
    db.execute(&query, rusqlite::params![req.signature, now, ip, ua, token])
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: e.to_string(),
                }),
            )
        })?;

    // Check if both signed now
    let (cs, cls): (Option<String>, Option<String>) = db
        .query_row(
            "SELECT creator_signature, client_signature FROM contracts WHERE token = ?1",
            rusqlite::params![token],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: e.to_string(),
                }),
            )
        })?;

    let new_status = if cs.is_some() && cls.is_some() {
        "completed"
    } else if cs.is_some() {
        "creator_signed"
    } else {
        "pending"
    };

    db.execute(
        "UPDATE contracts SET status = ?1 WHERE token = ?2",
        rusqlite::params![new_status, token],
    )
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    // Audit log
    let contract_id: String = db.query_row(
        "SELECT id FROM contracts WHERE token = ?1",
        rusqlite::params![token],
        |row| row.get(0),
    ).unwrap_or_default();
    let action = format!("{}_signed", req.signer);
    db::append_audit_log(&db, &contract_id, &action, &ip, &ua, &format!("status: {}", new_status));

    let message = if new_status == "completed" {
        "両者の署名が完了しました。契約が成立しました。"
    } else {
        "署名が完了しました。"
    };

    Ok(Json(SignResponse {
        success: true,
        status: new_status.to_string(),
        message: message.to_string(),
    }))
}

async fn verify_email(
    State(state): State<AppState>,
    Path(token): Path<String>,
    Json(req): Json<VerifyEmailRequest>,
) -> Json<serde_json::Value> {
    let email = req.email.trim().to_lowercase();
    let db = state.db.lock().unwrap();
    let result: Result<(Option<String>, Option<String>, String, String), _> = db.query_row(
        "SELECT client_email, creator_email, client_name, creator_name FROM contracts WHERE token = ?1",
        rusqlite::params![token],
        |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
    );
    drop(db);

    match result {
        Err(_) => Json(serde_json::json!({"ok": false, "error": "Contract not found"})),
        Ok((client_email, creator_email, client_name, creator_name)) => {
            let client_match = client_email.as_deref()
                .map(|e| e.trim().to_lowercase() == email)
                .unwrap_or(false);
            let creator_match = creator_email.as_deref()
                .map(|e| e.trim().to_lowercase() == email)
                .unwrap_or(false);
            let no_emails = client_email.as_deref().unwrap_or("").is_empty()
                && creator_email.as_deref().unwrap_or("").is_empty();

            if client_match {
                Json(serde_json::json!({"ok": true, "role": "client", "name": client_name}))
            } else if creator_match {
                Json(serde_json::json!({"ok": true, "role": "creator", "name": creator_name}))
            } else if no_emails {
                // No emails configured — allow anyone, role unknown
                Json(serde_json::json!({"ok": true, "role": "unknown", "name": ""}))
            } else {
                Json(serde_json::json!({"ok": false, "error": "メールアドレスが一致しません"}))
            }
        }
    }
}

async fn verify_contract(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ErrorResponse>)> {
    let db = state.db.lock().unwrap();
    let (body_text, document_hash, creator_sig, client_sig, creator_signed_at, client_signed_at, audit_log): (String, Option<String>, Option<String>, Option<String>, Option<String>, Option<String>, String) = db
        .query_row(
            "SELECT body_text, document_hash, creator_signature, client_signature, creator_signed_at, client_signed_at, COALESCE(audit_log, '[]') FROM contracts WHERE id = ?1",
            rusqlite::params![id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?, row.get(4)?, row.get(5)?, row.get(6)?)),
        )
        .map_err(|_| (StatusCode::NOT_FOUND, Json(ErrorResponse { error: "Contract not found".to_string() })))?;

    let current_hash = sha256_hex(&body_text);
    let stored_hash = document_hash.unwrap_or_default();
    let integrity = !stored_hash.is_empty() && stored_hash == current_hash;
    let audit: serde_json::Value = serde_json::from_str(&audit_log).unwrap_or(serde_json::json!([]));

    Ok(Json(serde_json::json!({
        "document_hash": stored_hash,
        "body_hash_current": current_hash,
        "integrity": integrity,
        "creator_signed": creator_sig.is_some(),
        "creator_signed_at": creator_signed_at,
        "client_signed": client_sig.is_some(),
        "client_signed_at": client_signed_at,
        "audit_log": audit
    })))
}

async fn get_templates() -> Json<Vec<templates_data::ContractTemplate>> {
    Json(templates_data::get_templates())
}

async fn download_pdf(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<impl IntoResponse, (StatusCode, Json<ErrorResponse>)> {
    // Simple text-based "PDF" placeholder - a real implementation would use a PDF library
    let db = state.db.lock().unwrap();
    let (title, body, status): (String, String, String) = db
        .query_row(
            "SELECT title, body_text, status FROM contracts WHERE id = ?1",
            rusqlite::params![id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
        )
        .map_err(|_| {
            (
                StatusCode::NOT_FOUND,
                Json(ErrorResponse {
                    error: "Contract not found".to_string(),
                }),
            )
        })?;

    if status != "completed" {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Contract is not yet fully signed".to_string(),
            }),
        ));
    }

    // Return contract text as plain text download for now
    let content = format!("{}\n\n{}\n\n--- 署名済み ---", title, body);
    let headers = [
        (
            axum::http::header::CONTENT_TYPE,
            "text/plain; charset=utf-8",
        ),
        (
            axum::http::header::CONTENT_DISPOSITION,
            "attachment; filename=\"contract.txt\"",
        ),
    ];

    Ok((headers, content))
}

#[allow(clippy::too_many_arguments)]
fn render_sign_page(
    _id: &str,
    token: &str,
    title: &str,
    client_name: &str,
    type_label: &str,
    amount_display: &str,
    start_display: &str,
    end_display: &str,
    body_html: &str,
    creator_name: &str,
    creator_signed: bool,
    client_signed: bool,
    both_signed: bool,
    creator_sig_data: Option<&str>,
    client_sig_data: Option<&str>,
    creator_signed_at: Option<&str>,
    client_signed_at: Option<&str>,
    status: &str,
) -> String {
    let status_badge = match status {
        "completed" => r#"<span class="badge badge-complete">契約完了</span>"#,
        "creator_signed" => r#"<span class="badge badge-partial">作成者署名済</span>"#,
        _ => r#"<span class="badge badge-pending">署名待ち</span>"#,
    };

    let signatures_html = {
        let mut s = String::new();
        s.push_str(r#"<div class="signatures-row">"#);

        // Creator signature
        s.push_str(r#"<div class="sig-block">"#);
        s.push_str(&format!(r#"<div class="sig-label">甲（作成者）: {}</div>"#, creator_name));
        if let Some(sig) = creator_sig_data {
            s.push_str(&format!(r#"<img class="sig-img" src="{}" alt="Creator signature"/>"#, sig));
            if let Some(at) = creator_signed_at {
                s.push_str(&format!(r#"<div class="sig-date">署名日: {}</div>"#, at));
            }
        } else {
            s.push_str(r#"<div class="sig-placeholder">未署名</div>"#);
        }
        s.push_str("</div>");

        // Client signature
        s.push_str(r#"<div class="sig-block">"#);
        s.push_str(&format!(r#"<div class="sig-label">乙（署名者）: {}</div>"#, client_name));
        if let Some(sig) = client_sig_data {
            s.push_str(&format!(r#"<img class="sig-img" src="{}" alt="Client signature"/>"#, sig));
            if let Some(at) = client_signed_at {
                s.push_str(&format!(r#"<div class="sig-date">署名日: {}</div>"#, at));
            }
        } else {
            s.push_str(r#"<div class="sig-placeholder">未署名</div>"#);
        }
        s.push_str("</div>");

        s.push_str("</div>");
        s
    };

    let canvas_section = if both_signed {
        format!(r#"
        <div class="complete-banner">
            <div class="complete-icon">&#10003;</div>
            <h2>契約完了</h2>
            <p>両者の署名が完了し、契約が成立しました。</p>
        </div>
        <div id="confetti-container"></div>
        <script>
        (function() {{
            const container = document.getElementById('confetti-container');
            const colors = ['#7B2FBE','#4CC9F0','#F72585','#4361EE','#3A0CA3'];
            for (let i = 0; i < 80; i++) {{
                const c = document.createElement('div');
                c.className = 'confetti';
                c.style.left = Math.random()*100 + '%';
                c.style.backgroundColor = colors[Math.floor(Math.random()*colors.length)];
                c.style.animationDelay = Math.random()*3 + 's';
                c.style.animationDuration = (2+Math.random()*3) + 's';
                container.appendChild(c);
            }}
        }})();
        </script>"#)
    } else {
        // pre-determine signer based on who has already signed
        let forced_signer = if creator_signed && !client_signed {
            "client"
        } else if !creator_signed && client_signed {
            "creator"
        } else {
            ""  // both unsigned: determine from email
        };

        format!(r##"
        <!-- Step 1: Email verification -->
        <div id="email-step" class="canvas-section">
            <h3>本人確認</h3>
            <p style="font-size:13px;color:#aaa;margin-bottom:16px;">署名する前にメールアドレスを入力してください</p>
            <input type="email" id="verify-email-input" placeholder="your@email.com"
                style="width:100%;padding:14px;background:rgba(0,0,0,0.3);border:1px solid rgba(255,255,255,0.1);
                       border-radius:10px;color:#e0e0e0;font-size:16px;outline:none;margin-bottom:12px;">
            <div id="email-error" style="color:#f44;font-size:13px;margin-bottom:12px;display:none;"></div>
            <button type="button" id="btn-verify-email" class="btn btn-primary">確認して署名へ進む</button>
            <div id="email-loading" class="loading" style="display:none;">
                <div class="spinner"></div><span>確認中...</span>
            </div>
        </div>

        <!-- Step 2: Signature canvas (hidden until email verified) -->
        <div id="sig-step" class="canvas-section" style="display:none;">
            <h3>署名欄</h3>
            <p id="signer-info-label" class="signer-info"></p>
            <input type="hidden" id="resolved-signer" value="{forced_signer}">
            <div class="canvas-wrapper">
                <canvas id="sig-canvas" width="400" height="200"></canvas>
            </div>
            <div class="canvas-buttons">
                <button type="button" id="btn-clear" class="btn btn-secondary">クリア</button>
                <button type="button" id="btn-undo" class="btn btn-secondary">元に戻す</button>
            </div>
            <label style="display:flex;align-items:flex-start;gap:10px;margin:16px 0;font-size:13px;color:#ccc;cursor:pointer;line-height:1.6;">
                <input type="checkbox" id="agree-check" style="margin-top:4px;accent-color:#7B2FBE;width:18px;height:18px;flex-shrink:0;">
                本契約書の内容を確認し、電子署名法に基づく電子署名として法的拘束力を持つことを理解した上で署名します。
            </label>
            <button type="button" id="btn-sign" class="btn btn-primary" disabled style="opacity:0.4;">署名する</button>
            <script>document.getElementById('agree-check').addEventListener('change',function(){{const b=document.getElementById('btn-sign');b.disabled=!this.checked;b.style.opacity=this.checked?'1':'0.4';}});</script>
            <div id="loading" class="loading" style="display:none;">
                <div class="spinner"></div><span>送信中...</span>
            </div>
            <div id="success-msg" class="success-msg" style="display:none;">
                <div class="success-icon">&#10003;</div>
                <p>署名が完了しました!</p>
            </div>
        </div>

        <script>
        (function() {{
            const token = '{token}';

            // --- Email verification ---
            const emailInput = document.getElementById('verify-email-input');
            const btnVerify = document.getElementById('btn-verify-email');
            const emailError = document.getElementById('email-error');
            const emailLoading = document.getElementById('email-loading');

            // Allow Enter key in email input
            emailInput.addEventListener('keydown', function(e) {{
                if (e.key === 'Enter') btnVerify.click();
            }});

            btnVerify.addEventListener('click', async function() {{
                const email = emailInput.value.trim();
                if (!email || !email.includes('@')) {{
                    emailError.textContent = '有効なメールアドレスを入力してください';
                    emailError.style.display = 'block';
                    return;
                }}
                emailError.style.display = 'none';
                btnVerify.style.display = 'none';
                emailLoading.style.display = 'flex';

                try {{
                    const res = await fetch('/api/sign/' + token + '/verify-email', {{
                        method: 'POST',
                        headers: {{ 'Content-Type': 'application/json' }},
                        body: JSON.stringify({{ email }})
                    }});
                    const data = await res.json();
                    emailLoading.style.display = 'none';
                    if (data.ok) {{
                        document.getElementById('email-step').style.display = 'none';
                        document.getElementById('sig-step').style.display = 'block';
                        // Set signer role
                        const forcedSigner = document.getElementById('resolved-signer').value;
                        let signer = forcedSigner;
                        if (!signer && data.role !== 'unknown') signer = data.role;
                        if (!signer) signer = 'client'; // default
                        document.getElementById('resolved-signer').value = signer;
                        const label = signer === 'creator' ? '甲（作成者）として署名します' : '乙（署名者）として署名します';
                        document.getElementById('signer-info-label').textContent = label;
                        initCanvas();
                    }} else {{
                        emailError.textContent = data.error || 'メールアドレスが確認できません';
                        emailError.style.display = 'block';
                        btnVerify.style.display = 'block';
                    }}
                }} catch(err) {{
                    emailLoading.style.display = 'none';
                    emailError.textContent = '通信エラー: ' + err.message;
                    emailError.style.display = 'block';
                    btnVerify.style.display = 'block';
                }}
            }});

            // --- Signature canvas ---
            function initCanvas() {{
                const canvas = document.getElementById('sig-canvas');
                const ctx = canvas.getContext('2d');
                let drawing = false;
                let paths = [];
                let currentPath = [];

                const dpr = window.devicePixelRatio || 1;
                const rect = canvas.getBoundingClientRect();
                canvas.width = rect.width * dpr;
                canvas.height = rect.height * dpr;
                ctx.scale(dpr, dpr);
                canvas.style.width = rect.width + 'px';
                canvas.style.height = rect.height + 'px';

                function getPos(e) {{
                    const r = canvas.getBoundingClientRect();
                    const t = e.touches ? e.touches[0] : e;
                    return {{ x: t.clientX - r.left, y: t.clientY - r.top }};
                }}
                function startDraw(e) {{ e.preventDefault(); drawing = true; currentPath = [getPos(e)]; }}
                function draw(e) {{
                    if (!drawing) return;
                    e.preventDefault();
                    currentPath.push(getPos(e));
                    redraw();
                }}
                function endDraw(e) {{
                    if (!drawing) return;
                    e.preventDefault();
                    drawing = false;
                    if (currentPath.length > 1) paths.push([...currentPath]);
                    currentPath = [];
                }}
                function redraw() {{
                    ctx.clearRect(0, 0, canvas.width / dpr, canvas.height / dpr);
                    ctx.strokeStyle = '#1a1a2e';
                    ctx.lineWidth = 2.5;
                    ctx.lineCap = 'round';
                    ctx.lineJoin = 'round';
                    for (const path of [...paths, currentPath]) {{
                        if (path.length < 2) continue;
                        ctx.beginPath();
                        ctx.moveTo(path[0].x, path[0].y);
                        for (let i = 1; i < path.length; i++) {{
                            const mid = {{ x: (path[i-1].x + path[i].x) / 2, y: (path[i-1].y + path[i].y) / 2 }};
                            ctx.quadraticCurveTo(path[i-1].x, path[i-1].y, mid.x, mid.y);
                        }}
                        ctx.stroke();
                    }}
                }}
                canvas.addEventListener('mousedown', startDraw);
                canvas.addEventListener('mousemove', draw);
                canvas.addEventListener('mouseup', endDraw);
                canvas.addEventListener('mouseleave', endDraw);
                canvas.addEventListener('touchstart', startDraw, {{ passive: false }});
                canvas.addEventListener('touchmove', draw, {{ passive: false }});
                canvas.addEventListener('touchend', endDraw);
                document.getElementById('btn-clear').addEventListener('click', () => {{ paths=[]; currentPath=[]; redraw(); }});
                document.getElementById('btn-undo').addEventListener('click', () => {{ paths.pop(); redraw(); }});

                document.getElementById('btn-sign').addEventListener('click', async function() {{
                    if (paths.length === 0) {{ alert('署名を描いてください'); return; }}
                    const signer = document.getElementById('resolved-signer').value || 'client';
                    const exportCanvas = document.createElement('canvas');
                    exportCanvas.width = 400; exportCanvas.height = 200;
                    const ectx = exportCanvas.getContext('2d');
                    ectx.fillStyle = '#ffffff';
                    ectx.fillRect(0, 0, 400, 200);
                    ectx.strokeStyle = '#1a1a2e';
                    ectx.lineWidth = 2.5;
                    ectx.lineCap = 'round';
                    ectx.lineJoin = 'round';
                    for (const path of paths) {{
                        if (path.length < 2) continue;
                        ectx.beginPath();
                        ectx.moveTo(path[0].x, path[0].y);
                        for (let i = 1; i < path.length; i++) {{
                            const mid = {{ x: (path[i-1].x + path[i].x) / 2, y: (path[i-1].y + path[i].y) / 2 }};
                            ectx.quadraticCurveTo(path[i-1].x, path[i-1].y, mid.x, mid.y);
                        }}
                        ectx.stroke();
                    }}
                    const signature = exportCanvas.toDataURL('image/png');
                    document.getElementById('loading').style.display = 'flex';
                    document.getElementById('btn-sign').style.display = 'none';
                    try {{
                        const res = await fetch('/api/sign/' + token, {{
                            method: 'POST',
                            headers: {{ 'Content-Type': 'application/json' }},
                            body: JSON.stringify({{ signer, signature }})
                        }});
                        const data = await res.json();
                        document.getElementById('loading').style.display = 'none';
                        if (data.success) {{
                            document.getElementById('success-msg').style.display = 'block';
                            document.querySelector('#sig-step h3').textContent = '署名完了';
                            document.querySelector('.canvas-wrapper').style.display = 'none';
                            document.querySelector('.canvas-buttons').style.display = 'none';
                            if (data.status === 'completed') {{ setTimeout(() => location.reload(), 1500); }}
                        }} else {{
                            alert('エラー: ' + (data.error || '署名に失敗しました'));
                            document.getElementById('btn-sign').style.display = 'block';
                        }}
                    }} catch(err) {{
                        document.getElementById('loading').style.display = 'none';
                        document.getElementById('btn-sign').style.display = 'block';
                        alert('通信エラー: ' + err.message);
                    }}
                }});
            }}
        }})();
        </script>"##)
    };

    format!(r##"<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} - Pon 電子署名</title>
<meta property="og:title" content="{title} - Pon 電子署名">
<meta property="og:description" content="{creator_name}さんから署名のリクエストが届いています。Ponで安全に電子署名できます。">
<meta property="og:type" content="website">
<meta property="og:url" content="https://pon.enablerdao.com/sign/{token}">
<meta property="og:image" content="https://pon.enablerdao.com/ogp.png">
<meta property="og:site_name" content="Pon - 電子契約サービス">
<meta property="og:locale" content="ja_JP">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{title} - Pon 電子署名">
<meta name="twitter:description" content="{creator_name}さんから署名のリクエストが届いています。">
<meta name="twitter:image" content="https://pon.enablerdao.com/ogp.png">
<meta name="description" content="Ponで電子契約書に署名できます。安全・簡単・法的有効な電子署名サービス。">
<link rel="icon" type="image/png" href="/favicon.png">
<style>
*,*::before,*::after {{ box-sizing:border-box; margin:0; padding:0; }}
body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Hiragino Sans', sans-serif;
    background: #0F0F1A;
    color: #e0e0e0;
    min-height: 100vh;
}}
.container {{ max-width: 680px; margin: 0 auto; padding: 20px 16px 40px; }}
.header {{
    text-align: center;
    padding: 24px 0 16px;
}}
.logo {{
    font-size: 28px;
    font-weight: 700;
    background: linear-gradient(135deg, #7B2FBE, #4CC9F0);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    letter-spacing: 2px;
}}
.logo-sub {{ font-size: 12px; color: #888; margin-top: 4px; }}
.card {{
    background: #16213E;
    border-radius: 16px;
    padding: 24px;
    margin-bottom: 16px;
    border: 1px solid rgba(123,47,190,0.2);
}}
.card-title {{
    font-size: 20px;
    font-weight: 600;
    margin-bottom: 16px;
    color: #fff;
}}
.meta-row {{
    display: flex;
    justify-content: space-between;
    padding: 8px 0;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    font-size: 14px;
}}
.meta-label {{ color: #888; }}
.meta-value {{ color: #e0e0e0; font-weight: 500; }}
.badge {{
    display: inline-block;
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
}}
.badge-pending {{ background: rgba(255,193,7,0.15); color: #FFC107; }}
.badge-partial {{ background: rgba(76,201,240,0.15); color: #4CC9F0; }}
.badge-complete {{ background: rgba(76,175,80,0.15); color: #4CAF50; }}
.body-text {{
    max-height: 400px;
    overflow-y: auto;
    padding: 16px;
    background: rgba(0,0,0,0.2);
    border-radius: 12px;
    font-size: 13px;
    line-height: 1.8;
    color: #ccc;
    margin-top: 12px;
    white-space: pre-wrap;
    word-wrap: break-word;
}}
.body-text::-webkit-scrollbar {{ width: 6px; }}
.body-text::-webkit-scrollbar-thumb {{ background: #333; border-radius: 3px; }}
.signatures-row {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin-top: 12px;
}}
.sig-block {{
    background: rgba(0,0,0,0.2);
    border-radius: 12px;
    padding: 12px;
    text-align: center;
}}
.sig-label {{ font-size: 12px; color: #888; margin-bottom: 8px; }}
.sig-img {{ max-width: 100%; height: 80px; object-fit: contain; background: #fff; border-radius: 8px; }}
.sig-date {{ font-size: 11px; color: #666; margin-top: 4px; }}
.sig-placeholder {{
    height: 80px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #555;
    font-size: 13px;
    border: 1px dashed #333;
    border-radius: 8px;
}}
.canvas-section {{ margin-top: 8px; }}
.canvas-section h3 {{ margin-bottom: 12px; color: #fff; font-size: 16px; }}
.signer-select {{
    display: flex;
    gap: 16px;
    margin-bottom: 12px;
    font-size: 14px;
}}
.signer-select label {{
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
    color: #ccc;
}}
.signer-info {{ font-size: 14px; color: #4CC9F0; margin-bottom: 12px; }}
.canvas-wrapper {{
    background: #fff;
    border-radius: 12px;
    padding: 4px;
    touch-action: none;
}}
#sig-canvas {{
    width: 100%;
    height: 200px;
    display: block;
    border-radius: 8px;
    cursor: crosshair;
    touch-action: none;
}}
.canvas-buttons {{
    display: flex;
    gap: 8px;
    margin: 12px 0;
}}
.btn {{
    padding: 12px 24px;
    border: none;
    border-radius: 12px;
    font-size: 15px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
}}
.btn-primary {{
    width: 100%;
    background: linear-gradient(135deg, #7B2FBE, #5B1F9E);
    color: #fff;
    font-size: 17px;
    padding: 16px;
}}
.btn-primary:hover {{ transform: translateY(-1px); box-shadow: 0 4px 20px rgba(123,47,190,0.4); }}
.btn-secondary {{
    background: rgba(255,255,255,0.08);
    color: #ccc;
    flex: 1;
}}
.btn-secondary:hover {{ background: rgba(255,255,255,0.12); }}
.loading {{
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 12px;
    padding: 16px;
    color: #4CC9F0;
}}
.spinner {{
    width: 24px; height: 24px;
    border: 3px solid rgba(76,201,240,0.2);
    border-top-color: #4CC9F0;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
}}
@keyframes spin {{ to {{ transform: rotate(360deg); }} }}
.success-msg {{
    text-align: center;
    padding: 24px;
}}
.success-icon {{
    width: 56px; height: 56px;
    background: linear-gradient(135deg, #4CAF50, #2E7D32);
    color: #fff;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 28px;
    margin: 0 auto 12px;
    animation: popIn 0.4s ease;
}}
@keyframes popIn {{
    0% {{ transform: scale(0); }}
    70% {{ transform: scale(1.15); }}
    100% {{ transform: scale(1); }}
}}
.success-msg p {{ color: #4CAF50; font-size: 16px; font-weight: 600; }}
.complete-banner {{
    text-align: center;
    padding: 32px 16px;
    background: linear-gradient(135deg, rgba(76,175,80,0.1), rgba(76,201,240,0.1));
    border-radius: 16px;
    border: 1px solid rgba(76,175,80,0.3);
}}
.complete-icon {{
    width: 64px; height: 64px;
    background: linear-gradient(135deg, #4CAF50, #2E7D32);
    color: #fff;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 32px;
    margin: 0 auto 16px;
    animation: popIn 0.6s ease;
}}
.complete-banner h2 {{ color: #4CAF50; margin-bottom: 8px; }}
.complete-banner p {{ color: #888; font-size: 14px; }}
#confetti-container {{
    position: fixed;
    top: 0; left: 0;
    width: 100%; height: 100%;
    pointer-events: none;
    overflow: hidden;
    z-index: 999;
}}
.confetti {{
    position: absolute;
    top: -10px;
    width: 8px; height: 8px;
    border-radius: 2px;
    animation: confettiFall 3s ease-in forwards;
    opacity: 0.8;
}}
@keyframes confettiFall {{
    0% {{ transform: translateY(0) rotate(0deg); opacity: 1; }}
    100% {{ transform: translateY(100vh) rotate(720deg); opacity: 0; }}
}}
.footer {{
    text-align: center;
    padding: 24px 0;
    font-size: 12px;
    color: #555;
}}
.app-banner {{
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(123,47,190,0.1);
    border: 1px solid rgba(123,47,190,0.25);
    border-radius: 14px;
    padding: 14px 18px;
    margin-bottom: 12px;
}}
.app-banner-title {{ font-size: 14px; font-weight: 700; color: #fff; }}
.app-banner-sub {{ font-size: 11px; color: #aaa; margin-top: 2px; }}
.app-store-btn {{
    display: flex;
    align-items: center;
    gap: 6px;
    background: #7B2FBE;
    color: #fff;
    text-decoration: none;
    padding: 9px 16px;
    border-radius: 10px;
    font-size: 13px;
    font-weight: 600;
    white-space: nowrap;
    transition: background 0.2s;
}}
.app-store-btn:hover {{ background: #9B4FDE; }}
@media (max-width: 480px) {{
    .signatures-row {{ grid-template-columns: 1fr; }}
    .card {{ padding: 16px; }}
    .signer-select {{ flex-direction: column; gap: 8px; }}
}}
</style>
</head>
<body>
<div class="container">
    <div class="header">
        <div class="logo">Pon</div>
        <div class="logo-sub">電子契約サービス</div>
    </div>

    <div class="card">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
            <div class="card-title">{title}</div>
            {status_badge}
        </div>
        <div class="meta-row">
            <span class="meta-label">契約種別</span>
            <span class="meta-value">{type_label}</span>
        </div>
        <div class="meta-row">
            <span class="meta-label">甲（作成者）</span>
            <span class="meta-value">{creator_name}</span>
        </div>
        <div class="meta-row">
            <span class="meta-label">乙（署名者）</span>
            <span class="meta-value">{client_name}</span>
        </div>
        <div class="meta-row">
            <span class="meta-label">金額</span>
            <span class="meta-value">{amount_display}</span>
        </div>
        <div class="meta-row">
            <span class="meta-label">期間</span>
            <span class="meta-value">{start_display} 〜 {end_display}</span>
        </div>
    </div>

    <div class="card">
        <div class="card-title">契約内容</div>
        <div class="body-text">{body_html}</div>
    </div>

    <div class="card">
        <div class="card-title">署名状況</div>
        {signatures_html}
    </div>

    <div class="card">
        {canvas_section}
    </div>

    <div class="app-banner">
        <div class="app-banner-text">
            <div class="app-banner-title">Ponアプリで管理</div>
            <div class="app-banner-sub">iPhoneで契約書を作成・署名・管理</div>
        </div>
        <a href="https://testflight.apple.com/join/XyZdmPVt" target="_blank" class="app-store-btn">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="white"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
            TestFlightで試す
        </a>
    </div>
    <div class="footer">
        Powered by Pon &mdash; Secure Digital Contracts
    </div>
</div>
</body>
</html>"##)
}

async fn ogp_image() -> impl axum::response::IntoResponse {
    static OGP_PNG: &[u8] = include_bytes!("../static/ogp.png");
    (
        axum::http::StatusCode::OK,
        [
            (axum::http::header::CONTENT_TYPE, "image/png"),
            (axum::http::header::CACHE_CONTROL, "public, max-age=86400"),
        ],
        OGP_PNG,
    )
}

async fn favicon_image() -> impl axum::response::IntoResponse {
    static FAVICON_PNG: &[u8] = include_bytes!("../static/favicon.png");
    (
        axum::http::StatusCode::OK,
        [
            (axum::http::header::CONTENT_TYPE, "image/png"),
            (axum::http::header::CACHE_CONTROL, "public, max-age=86400"),
        ],
        FAVICON_PNG,
    )
}

async fn delete_contract(
    State(state): State<AppState>,
    Path(token): Path<String>,
    headers: axum::http::HeaderMap,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ErrorResponse>)> {
    let admin_key = headers.get("X-Admin-Key")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    let admin_secret = env::var("ADMIN_KEY").unwrap_or_default();
    if admin_secret.is_empty() || admin_key != admin_secret {
        return Err((StatusCode::UNAUTHORIZED, Json(ErrorResponse { error: "Unauthorized".to_string() })));
    }
    let db = state.db.lock().unwrap();
    let deleted = db.execute("DELETE FROM contracts WHERE token = ?1", rusqlite::params![token])
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ErrorResponse { error: e.to_string() })))?;
    Ok(Json(serde_json::json!({ "deleted": deleted })))
}

#[tokio::main]
async fn main() {
    let data_dir = env::var("DATA_DIR").unwrap_or_else(|_| "./data".to_string());
    std::fs::create_dir_all(&data_dir).ok();

    let base_url = env::var("BASE_URL").unwrap_or_else(|_| "https://pon.enablerdao.com".to_string());

    let db = db::init_db(&data_dir);
    let rate_limiter: RateLimiter = Arc::new(Mutex::new(HashMap::new()));
    let state = AppState { db, base_url, rate_limiter };

    let cors = CorsLayer::new()
        .allow_origin(AllowOrigin::predicate(|origin, _| {
            let o = origin.as_bytes();
            o == b"https://pon.enablerdao.com"
                || o == b"https://pon.enablerdao.com"
                || o.starts_with(b"http://localhost")
                || o.starts_with(b"http://127.0.0.1")
        }))
        .allow_methods([axum::http::Method::GET, axum::http::Method::POST, axum::http::Method::DELETE])
        .allow_headers([axum::http::header::CONTENT_TYPE]);

    let app = Router::new()
        .route("/", get(landing_page))
        .route("/health", get(health))
        .route("/privacy", get(privacy_page))
        .route("/terms", get(terms_page))
        .route("/dashboard", get(dashboard_page))
        .route("/api/contracts", post(create_contract))
        .route("/api/contracts/{id}", get(get_contract))
        .route("/api/contracts/token/{token}", get(get_contract_by_token).delete(delete_contract))
        .route("/api/contracts/{id}/pdf", get(download_pdf))
        .route("/api/contracts/{id}/verify", get(verify_contract))
        .route("/api/sign/{token}", post(submit_signature))
        .route("/api/sign/{token}/verify-email", post(verify_email))
        .route("/api/templates", get(get_templates))
        .route("/sign/{token}", get(sign_page))
        .route("/ogp.png", get(ogp_image))
        .route("/favicon.png", get(favicon_image))
        .layer(cors)
        .with_state(state);

    let port: u16 = env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8080);

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port))
        .await
        .expect("Failed to bind");

    println!("Pon signing server running on port {}", port);

    axum::serve(listener, app).await.expect("Server error");
}
