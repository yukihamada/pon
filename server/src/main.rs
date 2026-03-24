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
use tower_http::cors::CorsLayer;

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
}

// --- Request / Response types ---

#[derive(Deserialize)]
struct CreateContractRequest {
    title: String,
    client_name: String,
    client_email: Option<String>,
    contract_type: String,
    amount: Option<i64>,
    currency: Option<String>,
    start_date: Option<String>,
    end_date: Option<String>,
    body_text: String,
    creator_name: Option<String>,
    attachments_json: Option<String>,
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

async fn create_contract(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<CreateContractRequest>,
) -> Result<(StatusCode, Json<CreateContractResponse>), (StatusCode, Json<ErrorResponse>)> {
    let id = uuid::Uuid::new_v4().to_string();
    let token = uuid::Uuid::new_v4().to_string();
    let creator_name = req.creator_name.unwrap_or_else(|| "Yuki Hamada".to_string());
    let amount = req.amount.unwrap_or(0);
    let currency = req.currency.unwrap_or_else(|| "JPY".to_string());
    let attachments = req.attachments_json.unwrap_or_else(|| "[]".to_string());
    let document_hash = sha256_hex(&req.body_text);
    let ip = extract_ip(&headers);
    let ua = extract_ua(&headers);

    let db = state.db.lock().unwrap();
    db.execute(
        "INSERT INTO contracts (id, token, title, client_name, client_email, contract_type, amount, currency, start_date, end_date, body_text, creator_name, attachments_json, document_hash) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)",
        rusqlite::params![id, token, req.title, req.client_name, req.client_email, req.contract_type, amount, currency, req.start_date, req.end_date, req.body_text, creator_name, attachments, document_hash],
    ).map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(ErrorResponse { error: e.to_string() })))?;

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
            let token: String = row.get(1)?;
            let sign_url = format!("{}/sign/{}", "https://pon-sign.fly.dev", token);
            Ok(ContractResponse {
                id: row.get(0)?,
                token,
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
                sign_url,
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
        (StatusCode::NOT_FOUND, Html("<h1>Contract not found</h1>".to_string()))
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
    let start_display = start_date.unwrap_or_default();
    let end_display = end_date.unwrap_or_default();
    let body_html = body_text.replace('\n', "<br>");

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
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "signer must be 'creator' or 'client'".to_string(),
            }),
        ));
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

    let ip = extract_ip(&headers);
    let ua = extract_ua(&headers);

    let (sig_col, signed_at_col, ip_col, ua_col) = if req.signer == "creator" {
        ("creator_signature", "creator_signed_at", "creator_ip", "creator_user_agent")
    } else {
        ("client_signature", "client_signed_at", "client_ip", "client_user_agent")
    };

    let query = format!(
        "UPDATE contracts SET {} = ?1, {} = ?2, {} = ?3, {} = ?4 WHERE token = ?5",
        sig_col, signed_at_col, ip_col, ua_col
    );
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
        let signer_options = if !creator_signed && !client_signed {
            r#"<div class="signer-select">
                <label><input type="radio" name="signer" value="creator" checked> 甲（作成者）として署名</label>
                <label><input type="radio" name="signer" value="client"> 乙（署名者）として署名</label>
            </div>"#.to_string()
        } else if !creator_signed {
            r#"<input type="hidden" name="signer" value="creator">
            <p class="signer-info">甲（作成者）として署名してください</p>"#.to_string()
        } else {
            r#"<input type="hidden" name="signer" value="client">
            <p class="signer-info">乙（署名者）として署名してください</p>"#.to_string()
        };

        format!(r##"
        <div class="canvas-section">
            <h3>署名欄</h3>
            {signer_options}
            <div class="canvas-wrapper">
                <canvas id="sig-canvas" width="400" height="200"></canvas>
            </div>
            <div class="canvas-buttons">
                <button type="button" id="btn-clear" class="btn btn-secondary">クリア</button>
                <button type="button" id="btn-undo" class="btn btn-secondary">元に戻す</button>
            </div>
            <label style="display:flex;align-items:flex-start;gap:10px;margin:16px 0;font-size:13px;color:#ccc;cursor:pointer;line-height:1.6;">
                <input type="checkbox" id="agree-check" style="margin-top:4px;accent-color:#7B2FBE;width:18px;height:18px;flex-shrink:0;">
                本契約書の内容を確認し、電子署名法に基づく電子署名として、法的拘束力を持つことを理解した上で署名します。
            </label>
            <button type="button" id="btn-sign" class="btn btn-primary" disabled style="opacity:0.4;">署名する</button>
            <script>document.getElementById('agree-check').addEventListener('change',function(){{const b=document.getElementById('btn-sign');b.disabled=!this.checked;b.style.opacity=this.checked?'1':'0.4';}});</script>
            <div id="loading" class="loading" style="display:none;">
                <div class="spinner"></div>
                <span>送信中...</span>
            </div>
            <div id="success-msg" class="success-msg" style="display:none;">
                <div class="success-icon">&#10003;</div>
                <p>署名が完了しました!</p>
            </div>
        </div>
        <script>
        (function() {{
            const canvas = document.getElementById('sig-canvas');
            const ctx = canvas.getContext('2d');
            const token = '{token}';
            let drawing = false;
            let paths = [];
            let currentPath = [];

            // High DPI support
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

            function startDraw(e) {{
                e.preventDefault();
                drawing = true;
                currentPath = [getPos(e)];
            }}

            function draw(e) {{
                if (!drawing) return;
                e.preventDefault();
                const p = getPos(e);
                currentPath.push(p);
                redraw();
            }}

            function endDraw(e) {{
                if (!drawing) return;
                e.preventDefault();
                drawing = false;
                if (currentPath.length > 1) {{
                    paths.push([...currentPath]);
                }}
                currentPath = [];
            }}

            function redraw() {{
                ctx.clearRect(0, 0, canvas.width / dpr, canvas.height / dpr);
                ctx.strokeStyle = '#1a1a2e';
                ctx.lineWidth = 2;
                ctx.lineCap = 'round';
                ctx.lineJoin = 'round';

                const allPaths = [...paths, currentPath];
                for (const path of allPaths) {{
                    if (path.length < 2) continue;
                    ctx.beginPath();
                    ctx.moveTo(path[0].x, path[0].y);
                    for (let i = 1; i < path.length; i++) {{
                        const mid = {{
                            x: (path[i-1].x + path[i].x) / 2,
                            y: (path[i-1].y + path[i].y) / 2
                        }};
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

            document.getElementById('btn-clear').addEventListener('click', function() {{
                paths = [];
                currentPath = [];
                redraw();
            }});

            document.getElementById('btn-undo').addEventListener('click', function() {{
                paths.pop();
                redraw();
            }});

            document.getElementById('btn-sign').addEventListener('click', async function() {{
                if (paths.length === 0) {{
                    alert('署名を描いてください');
                    return;
                }}

                const signerEl = document.querySelector('input[name="signer"]:checked') || document.querySelector('input[name="signer"]');
                const signer = signerEl.value;

                // Export at 1x for clean PNG
                const exportCanvas = document.createElement('canvas');
                exportCanvas.width = 400;
                exportCanvas.height = 200;
                const ectx = exportCanvas.getContext('2d');
                ectx.fillStyle = '#ffffff';
                ectx.fillRect(0, 0, 400, 200);
                ectx.strokeStyle = '#1a1a2e';
                ectx.lineWidth = 2;
                ectx.lineCap = 'round';
                ectx.lineJoin = 'round';
                for (const path of paths) {{
                    if (path.length < 2) continue;
                    ectx.beginPath();
                    ectx.moveTo(path[0].x, path[0].y);
                    for (let i = 1; i < path.length; i++) {{
                        const mid = {{
                            x: (path[i-1].x + path[i].x) / 2,
                            y: (path[i-1].y + path[i].y) / 2
                        }};
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
                        document.querySelector('.canvas-section h3').textContent = '署名完了';
                        document.querySelector('.canvas-wrapper').style.display = 'none';
                        document.querySelector('.canvas-buttons').style.display = 'none';
                        const sel = document.querySelector('.signer-select');
                        if (sel) sel.style.display = 'none';
                        const info = document.querySelector('.signer-info');
                        if (info) info.style.display = 'none';
                        if (data.status === 'completed') {{
                            setTimeout(() => location.reload(), 1500);
                        }}
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
        }})();
        </script>"##)
    };

    format!(r##"<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} - Pon 電子署名</title>
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

    <div class="footer">
        Powered by Pon &mdash; Secure Digital Contracts
    </div>
</div>
</body>
</html>"##)
}

#[tokio::main]
async fn main() {
    let data_dir = env::var("DATA_DIR").unwrap_or_else(|_| "./data".to_string());
    std::fs::create_dir_all(&data_dir).ok();

    let base_url = env::var("BASE_URL").unwrap_or_else(|_| "https://pon-sign.fly.dev".to_string());

    let db = db::init_db(&data_dir);
    let state = AppState { db, base_url };

    let cors = CorsLayer::permissive();

    let app = Router::new()
        .route("/", get(health))
        .route("/health", get(health))
        .route("/api/contracts", post(create_contract))
        .route("/api/contracts/{id}", get(get_contract))
        .route("/api/contracts/{id}/pdf", get(download_pdf))
        .route("/api/contracts/{id}/verify", get(verify_contract))
        .route("/api/sign/{token}", post(submit_signature))
        .route("/api/templates", get(get_templates))
        .route("/sign/{token}", get(sign_page))
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
