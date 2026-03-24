use rusqlite::Connection;
use std::path::Path;
use std::sync::{Arc, Mutex};

pub type Db = Arc<Mutex<Connection>>;

pub fn init_db(data_dir: &str) -> Db {
    let path = Path::new(data_dir).join("pon.db");
    let conn = Connection::open(&path).expect("Failed to open database");

    conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;")
        .expect("Failed to set pragmas");

    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS contracts (
            id TEXT PRIMARY KEY,
            token TEXT UNIQUE NOT NULL,
            title TEXT NOT NULL,
            client_name TEXT NOT NULL,
            client_email TEXT,
            contract_type TEXT NOT NULL,
            amount INTEGER DEFAULT 0,
            currency TEXT DEFAULT 'JPY',
            start_date TEXT,
            end_date TEXT,
            body_text TEXT NOT NULL,
            creator_name TEXT DEFAULT 'Yuki Hamada',
            creator_signature TEXT,
            client_signature TEXT,
            creator_signed_at TEXT,
            client_signed_at TEXT,
            status TEXT DEFAULT 'pending',
            created_at TEXT DEFAULT (datetime('now')),
            attachments_json TEXT DEFAULT '[]',
            document_hash TEXT,
            creator_ip TEXT,
            client_ip TEXT,
            creator_user_agent TEXT,
            client_user_agent TEXT,
            creator_email_verified INTEGER DEFAULT 0,
            client_email_verified INTEGER DEFAULT 0,
            agreement_text TEXT,
            audit_log TEXT DEFAULT '[]'
        );",
    )
    .expect("Failed to create table");

    // Migration: add new columns to existing tables
    let new_columns = [
        ("document_hash", "TEXT"),
        ("creator_ip", "TEXT"),
        ("client_ip", "TEXT"),
        ("creator_user_agent", "TEXT"),
        ("client_user_agent", "TEXT"),
        ("creator_email_verified", "INTEGER DEFAULT 0"),
        ("client_email_verified", "INTEGER DEFAULT 0"),
        ("agreement_text", "TEXT"),
        ("audit_log", "TEXT DEFAULT '[]'"),
    ];
    for (col, typ) in &new_columns {
        let sql = format!("ALTER TABLE contracts ADD COLUMN {} {}", col, typ);
        // Ignore errors (column already exists)
        let _ = conn.execute_batch(&sql);
    }

    Arc::new(Mutex::new(conn))
}

/// Append an entry to the audit_log JSON array for a contract.
pub fn append_audit_log(
    conn: &Connection,
    contract_id: &str,
    action: &str,
    ip: &str,
    user_agent: &str,
    detail: &str,
) {
    let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

    // Read current audit_log
    let current: String = conn
        .query_row(
            "SELECT COALESCE(audit_log, '[]') FROM contracts WHERE id = ?1",
            rusqlite::params![contract_id],
            |row| row.get(0),
        )
        .unwrap_or_else(|_| "[]".to_string());

    let mut log: Vec<serde_json::Value> =
        serde_json::from_str(&current).unwrap_or_else(|_| vec![]);

    log.push(serde_json::json!({
        "action": action,
        "timestamp": now,
        "ip": ip,
        "user_agent": user_agent,
        "detail": detail
    }));

    let updated = serde_json::to_string(&log).unwrap_or_else(|_| "[]".to_string());

    let _ = conn.execute(
        "UPDATE contracts SET audit_log = ?1 WHERE id = ?2",
        rusqlite::params![updated, contract_id],
    );
}
