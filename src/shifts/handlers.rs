use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    auth::jwt::Claims,
    errors::AppError,
    models::UserRole,
    permissions::checker::check_permission,
};

// ── Models ────────────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Shift {
    pub id:                       Uuid,
    pub branch_id:                Uuid,
    pub teller_id:                Uuid,
    pub teller_name:              String,
    pub status:                   String,
    pub opening_cash:             i32,
    pub opening_cash_original:    Option<i32>,
    pub opening_cash_was_edited:  bool,
    pub opening_cash_edit_reason: Option<String>,
    pub closing_cash_declared:    Option<i32>,
    pub closing_cash_system:      Option<i32>,
    pub cash_discrepancy:         Option<i32>,
    pub opened_at:                chrono::DateTime<chrono::Utc>,
    pub closed_at:                Option<chrono::DateTime<chrono::Utc>>,
    pub closed_by:                Option<Uuid>,
    pub force_closed_by:          Option<Uuid>,
    pub force_closed_at:          Option<chrono::DateTime<chrono::Utc>>,
    pub force_close_reason:       Option<String>,
    pub notes:                    Option<String>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct CashMovement {
    pub id:            Uuid,
    pub shift_id:      Uuid,
    pub amount:        i32,
    pub note:          String,
    pub moved_by:      Uuid,
    pub moved_by_name: String,
    pub created_at:    chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize)]
pub struct ShiftPreFill {
    pub has_open_shift:         bool,
    pub open_shift:             Option<Shift>,
    pub suggested_opening_cash: i32,
}

// ── Request types ─────────────────────────────────────────────

/// Client may supply its own UUID so offline-created shifts can be
/// synced without ID translation.  If omitted the server generates one.
#[derive(Deserialize)]
pub struct OpenShiftRequest {
    /// Client-generated UUID (offline support). Server uses it as the PK.
    pub id:                  Option<Uuid>,
    pub opening_cash:        i32,
    pub opening_cash_edited: Option<bool>,
    pub edit_reason:         Option<String>,
    /// ISO-8601 timestamp for when the shift was actually opened offline.
    /// If omitted, NOW() is used.
    pub opened_at:           Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Deserialize)]
pub struct CashMovementRequest {
    pub amount: i32,
    pub note:   String,
}

#[derive(Deserialize)]
pub struct InventoryCountInput {
    pub inventory_item_id: Uuid,
    pub actual_stock:      f64,
    pub note:              Option<String>,
}

#[derive(Deserialize)]
pub struct CloseShiftRequest {
    pub closing_cash_declared: i32,
    pub cash_note:             Option<String>,
    pub inventory_counts:      Vec<InventoryCountInput>,
    /// ISO-8601 timestamp for when the shift was actually closed offline.
    pub closed_at:             Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Deserialize)]
pub struct ForceCloseRequest {
    pub reason: Option<String>,
}

// ── GET /shifts/branches/:branch_id/current ───────────────────

pub async fn get_current_shift(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let open_shift = sqlx::query_as::<_, Shift>(
        r#"
        SELECT
            s.id, s.branch_id, s.teller_id,
            u.name AS teller_name,
            s.status::text,
            s.opening_cash, s.opening_cash_original,
            s.opening_cash_was_edited, s.opening_cash_edit_reason,
            s.closing_cash_declared, s.closing_cash_system, s.cash_discrepancy,
            s.opened_at, s.closed_at, s.closed_by,
            s.force_closed_by, s.force_closed_at, s.force_close_reason,
            s.notes
        FROM shifts s
        JOIN users u ON u.id = s.teller_id
        WHERE s.branch_id = $1 AND s.status = 'open'
        "#,
    )
    .bind(*branch_id)
    .fetch_optional(pool.get_ref())
    .await?;

    if let Some(shift) = open_shift {
        return Ok(HttpResponse::Ok().json(ShiftPreFill {
            has_open_shift:         true,
            open_shift:             Some(shift),
            suggested_opening_cash: 0,
        }));
    }

    let suggested: Option<i32> = sqlx::query_scalar(
        r#"
        SELECT closing_cash_declared
        FROM shifts
        WHERE branch_id = $1
          AND status IN ('closed', 'force_closed')
          AND closing_cash_declared IS NOT NULL
        ORDER BY closed_at DESC
        LIMIT 1
        "#,
    )
    .bind(*branch_id)
    .fetch_optional(pool.get_ref())
    .await?
    .flatten();

    Ok(HttpResponse::Ok().json(ShiftPreFill {
        has_open_shift:         false,
        open_shift:             None,
        suggested_opening_cash: suggested.unwrap_or(0),
    }))
}

// ── POST /shifts/branches/:branch_id/open ─────────────────────
//
// Idempotent: if a shift with the supplied `id` already exists for this
// branch, return it immediately (HTTP 200) instead of creating a duplicate.
// This lets the client safely retry after a network failure.

pub async fn open_shift(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
    body:      web::Json<OpenShiftRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "create").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let shift_id = body.id.unwrap_or_else(Uuid::new_v4);

    // ── Idempotency check: return existing shift if same UUID ─
    if let Some(existing) = sqlx::query_as::<_, Shift>(
        r#"
        SELECT
            s.id, s.branch_id, s.teller_id,
            u.name AS teller_name,
            s.status::text,
            s.opening_cash, s.opening_cash_original,
            s.opening_cash_was_edited, s.opening_cash_edit_reason,
            s.closing_cash_declared, s.closing_cash_system, s.cash_discrepancy,
            s.opened_at, s.closed_at, s.closed_by,
            s.force_closed_by, s.force_closed_at, s.force_close_reason,
            s.notes
        FROM shifts s
        JOIN users u ON u.id = s.teller_id
        WHERE s.id = $1 AND s.branch_id = $2
        "#,
    )
    .bind(shift_id)
    .bind(*branch_id)
    .fetch_optional(pool.get_ref())
    .await?
    {
        return Ok(HttpResponse::Ok().json(existing));
    }

    // ── Enforce one open shift per branch ─────────────────────
    let already_open: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM shifts WHERE branch_id = $1 AND status = 'open')"
    )
    .bind(*branch_id)
    .fetch_one(pool.get_ref())
    .await?;

    if already_open {
        return Err(AppError::Conflict(
            "A shift is already open for this branch".into(),
        ));
    }

    let was_edited = body.opening_cash_edited.unwrap_or(false);
    if was_edited && body.edit_reason.as_deref().unwrap_or("").trim().is_empty() {
        return Err(AppError::BadRequest(
            "edit_reason is required when opening cash is edited".into(),
        ));
    }

    let opened_at = body.opened_at.unwrap_or_else(chrono::Utc::now);

    let mut tx = pool.get_ref().begin().await?;

    let shift = sqlx::query_as::<_, Shift>(
        r#"
        INSERT INTO shifts
            (id, branch_id, teller_id, opening_cash, opening_cash_original,
             opening_cash_was_edited, opening_cash_edit_reason, opened_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING
            id, branch_id, teller_id,
            (SELECT name FROM users WHERE id = $3) AS teller_name,
            status::text,
            opening_cash, opening_cash_original,
            opening_cash_was_edited, opening_cash_edit_reason,
            closing_cash_declared, closing_cash_system, cash_discrepancy,
            opened_at, closed_at, closed_by,
            force_closed_by, force_closed_at, force_close_reason,
            notes
        "#,
    )
    .bind(shift_id)
    .bind(*branch_id)
    .bind(claims.user_id())
    .bind(body.opening_cash)
    .bind(body.opening_cash)
    .bind(was_edited)
    .bind(&body.edit_reason)
    .bind(opened_at)
    .fetch_one(&mut *tx)
    .await?;

    // Snapshot active inventory items for this branch
    sqlx::query(
        r#"
        INSERT INTO shift_inventory_snapshots (shift_id, inventory_item_id, stock_at_open)
        SELECT $1, id, current_stock
        FROM inventory_items
        WHERE branch_id = $2 AND deleted_at IS NULL AND is_active = true
        "#,
    )
    .bind(shift.id)
    .bind(*branch_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(HttpResponse::Created().json(shift))
}

// ── GET /shifts/branches/:branch_id ───────────────────────────

pub async fn list_shifts(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let shifts = sqlx::query_as::<_, Shift>(
        r#"
        SELECT
            s.id, s.branch_id, s.teller_id,
            u.name AS teller_name,
            s.status::text,
            s.opening_cash, s.opening_cash_original,
            s.opening_cash_was_edited, s.opening_cash_edit_reason,
            s.closing_cash_declared, s.closing_cash_system, s.cash_discrepancy,
            s.opened_at, s.closed_at, s.closed_by,
            s.force_closed_by, s.force_closed_at, s.force_close_reason,
            s.notes
        FROM shifts s
        JOIN users u ON u.id = s.teller_id
        WHERE s.branch_id = $1
        ORDER BY s.opened_at DESC
        "#,
    )
    .bind(*branch_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(shifts))
}

// ── GET /shifts/:shift_id ─────────────────────────────────────

pub async fn get_shift(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    shift_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "read").await?;

    let shift = fetch_shift_or_404(pool.get_ref(), *shift_id).await?;
    require_branch_access(pool.get_ref(), &claims, shift.branch_id).await?;

    Ok(HttpResponse::Ok().json(shift))
}

// ── POST /shifts/:shift_id/cash-movements ─────────────────────

pub async fn add_cash_movement(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    shift_id: web::Path<Uuid>,
    body:     web::Json<CashMovementRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "update").await?;

    let shift = fetch_shift_or_404(pool.get_ref(), *shift_id).await?;
    require_branch_access(pool.get_ref(), &claims, shift.branch_id).await?;

    if shift.status != "open" {
        return Err(AppError::BadRequest(
            "Cash movements can only be added to an open shift".into(),
        ));
    }
    if body.amount == 0 {
        return Err(AppError::BadRequest("Amount cannot be zero".into()));
    }
    if body.note.trim().is_empty() {
        return Err(AppError::BadRequest(
            "Note is required for cash movements".into(),
        ));
    }

    let movement = sqlx::query_as::<_, CashMovement>(
        r#"
        INSERT INTO shift_cash_movements (shift_id, amount, note, moved_by)
        VALUES ($1, $2, $3, $4)
        RETURNING
            id, shift_id, amount, note, moved_by,
            (SELECT name FROM users WHERE id = $4) AS moved_by_name,
            created_at
        "#,
    )
    .bind(*shift_id)
    .bind(body.amount)
    .bind(&body.note)
    .bind(claims.user_id())
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(movement))
}

// ── GET /shifts/:shift_id/cash-movements ──────────────────────

pub async fn list_cash_movements(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    shift_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "read").await?;

    let shift = fetch_shift_or_404(pool.get_ref(), *shift_id).await?;
    require_branch_access(pool.get_ref(), &claims, shift.branch_id).await?;

    let movements = sqlx::query_as::<_, CashMovement>(
        r#"
        SELECT
            m.id, m.shift_id, m.amount, m.note, m.moved_by,
            u.name AS moved_by_name,
            m.created_at
        FROM shift_cash_movements m
        JOIN users u ON u.id = m.moved_by
        WHERE m.shift_id = $1
        ORDER BY m.created_at ASC
        "#,
    )
    .bind(*shift_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(movements))
}

// ── POST /shifts/:shift_id/close ──────────────────────────────
//
// Idempotent: if the shift is already closed, return the existing data.

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct InventoryCountRow {
    pub inventory_item_id: Uuid,
    pub item_name:         String,
    pub unit:              String,
    pub expected_stock:    sqlx::types::BigDecimal,
    pub actual_stock:      sqlx::types::BigDecimal,
    pub discrepancy:       sqlx::types::BigDecimal,
    pub is_suspicious:     bool,
    pub note:              Option<String>,
}

#[derive(Debug, Serialize)]
pub struct CloseShiftResponse {
    pub shift:            Shift,
    pub inventory_counts: Vec<InventoryCountRow>,
}

pub async fn close_shift(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    shift_id: web::Path<Uuid>,
    body:     web::Json<CloseShiftRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "update").await?;

    let shift = fetch_shift_or_404(pool.get_ref(), *shift_id).await?;
    require_branch_access(pool.get_ref(), &claims, shift.branch_id).await?;

    // ── Idempotency: already closed → return existing data ────
    if shift.status != "open" {
        let existing_counts = sqlx::query_as::<_, InventoryCountRow>(
            r#"
            SELECT
                sic.inventory_item_id,
                ii.name AS item_name,
                ii.unit::text AS unit,
                sic.expected_stock,
                sic.actual_stock,
                sic.discrepancy,
                sic.is_suspicious,
                sic.note
            FROM shift_inventory_counts sic
            JOIN inventory_items ii ON ii.id = sic.inventory_item_id
            WHERE sic.shift_id = $1
            "#,
        )
        .bind(*shift_id)
        .fetch_all(pool.get_ref())
        .await?;

        return Ok(HttpResponse::Ok().json(CloseShiftResponse {
            shift,
            inventory_counts: existing_counts,
        }));
    }

    // ── Calculate expected cash ───────────────────────────────
    let cash_from_orders: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(SUM(total_amount), 0)::int
        FROM orders
        WHERE shift_id = $1
          AND payment_method = 'cash'
          AND status NOT IN ('voided', 'refunded')
        "#,
    )
    .bind(*shift_id)
    .fetch_one(pool.get_ref())
    .await?;

    let cash_movements_total: i32 = sqlx::query_scalar(
        "SELECT COALESCE(SUM(amount), 0)::int FROM shift_cash_movements WHERE shift_id = $1"
    )
    .bind(*shift_id)
    .fetch_one(pool.get_ref())
    .await?;

    let closing_cash_system = shift.opening_cash + cash_from_orders + cash_movements_total;

    let closed_at = body.closed_at.unwrap_or_else(chrono::Utc::now);

    let mut tx = pool.get_ref().begin().await?;

    let mut inventory_counts: Vec<InventoryCountRow> = Vec::new();

    for count in &body.inventory_counts {
        let snapshot: Option<sqlx::types::BigDecimal> = sqlx::query_scalar(
            "SELECT stock_at_open FROM shift_inventory_snapshots WHERE shift_id = $1 AND inventory_item_id = $2"
        )
        .bind(*shift_id)
        .bind(count.inventory_item_id)
        .fetch_optional(&mut *tx)
        .await?
        .flatten();

        let snapshot = match snapshot {
            Some(s) => s,
            None    => continue,
        };

        let consumed: sqlx::types::BigDecimal = sqlx::query_scalar(
            r#"
            SELECT COALESCE(SUM(quantity_deducted), 0)
            FROM inventory_deduction_logs
            WHERE order_id IN (SELECT id FROM orders WHERE shift_id = $1)
              AND inventory_item_id = $2
            "#,
        )
        .bind(*shift_id)
        .bind(count.inventory_item_id)
        .fetch_one(&mut *tx)
        .await?;

        let expected     = &snapshot - &consumed;
        let actual       = sqlx::types::BigDecimal::try_from(count.actual_stock)
            .map_err(|_| AppError::BadRequest("Invalid actual_stock value".into()))?;
        let is_suspicious = actual > expected;

        let row = sqlx::query_as::<_, InventoryCountRow>(
            r#"
            INSERT INTO shift_inventory_counts
                (shift_id, inventory_item_id, expected_stock, actual_stock, is_suspicious, note, counted_by)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            ON CONFLICT (shift_id, inventory_item_id)
            DO UPDATE SET
                actual_stock  = EXCLUDED.actual_stock,
                is_suspicious = EXCLUDED.is_suspicious,
                note          = EXCLUDED.note
            RETURNING
                inventory_item_id,
                (SELECT name FROM inventory_items WHERE id = $2) AS item_name,
                (SELECT unit::text FROM inventory_items WHERE id = $2) AS unit,
                expected_stock, actual_stock, discrepancy, is_suspicious, note
            "#,
        )
        .bind(*shift_id)
        .bind(count.inventory_item_id)
        .bind(&expected)
        .bind(&actual)
        .bind(is_suspicious)
        .bind(&count.note)
        .bind(claims.user_id())
        .fetch_one(&mut *tx)
        .await?;

        inventory_counts.push(row);
    }

    let closed_shift = sqlx::query_as::<_, Shift>(
        r#"
        UPDATE shifts SET
            status                = 'closed',
            closing_cash_declared = $2,
            closing_cash_system   = $3,
            closed_at             = $4,
            closed_by             = $5,
            notes                 = COALESCE($6, notes)
        WHERE id = $1
        RETURNING
            id, branch_id, teller_id,
            (SELECT name FROM users WHERE id = teller_id) AS teller_name,
            status::text,
            opening_cash, opening_cash_original,
            opening_cash_was_edited, opening_cash_edit_reason,
            closing_cash_declared, closing_cash_system, cash_discrepancy,
            opened_at, closed_at, closed_by,
            force_closed_by, force_closed_at, force_close_reason,
            notes
        "#,
    )
    .bind(*shift_id)
    .bind(body.closing_cash_declared)
    .bind(closing_cash_system)
    .bind(closed_at)
    .bind(claims.user_id())
    .bind(&body.cash_note)
    .fetch_one(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(HttpResponse::Ok().json(CloseShiftResponse {
        shift:            closed_shift,
        inventory_counts,
    }))
}

// ── POST /shifts/:shift_id/force-close ────────────────────────

pub async fn force_close_shift(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    shift_id: web::Path<Uuid>,
    body:     web::Json<ForceCloseRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "update").await?;

    let shift = fetch_shift_or_404(pool.get_ref(), *shift_id).await?;
    require_branch_access(pool.get_ref(), &claims, shift.branch_id).await?;

    match claims.role {
        UserRole::Teller => {
            return Err(AppError::Forbidden(
                "Only managers can force close a shift".into(),
            ));
        }
        _ => {}
    }

    if shift.status != "open" {
        return Err(AppError::BadRequest("Shift is not open".into()));
    }

    let closed = sqlx::query_as::<_, Shift>(
        r#"
        UPDATE shifts SET
            status             = 'force_closed',
            closed_at          = NOW(),
            closed_by          = $2,
            force_closed_by    = $2,
            force_closed_at    = NOW(),
            force_close_reason = $3
        WHERE id = $1
        RETURNING
            id, branch_id, teller_id,
            (SELECT name FROM users WHERE id = teller_id) AS teller_name,
            status::text,
            opening_cash, opening_cash_original,
            opening_cash_was_edited, opening_cash_edit_reason,
            closing_cash_declared, closing_cash_system, cash_discrepancy,
            opened_at, closed_at, closed_by,
            force_closed_by, force_closed_at, force_close_reason,
            notes
        "#,
    )
    .bind(*shift_id)
    .bind(claims.user_id())
    .bind(&body.reason)
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(closed))
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_shift_or_404(pool: &PgPool, shift_id: Uuid) -> Result<Shift, AppError> {
    sqlx::query_as::<_, Shift>(
        r#"
        SELECT
            s.id, s.branch_id, s.teller_id,
            u.name AS teller_name,
            s.status::text,
            s.opening_cash, s.opening_cash_original,
            s.opening_cash_was_edited, s.opening_cash_edit_reason,
            s.closing_cash_declared, s.closing_cash_system, s.cash_discrepancy,
            s.opened_at, s.closed_at, s.closed_by,
            s.force_closed_by, s.force_closed_at, s.force_close_reason,
            s.notes
        FROM shifts s
        JOIN users u ON u.id = s.teller_id
        WHERE s.id = $1
        "#,
    )
    .bind(shift_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Shift not found".into()))
}

async fn require_branch_access(
    pool:      &PgPool,
    claims:    &Claims,
    branch_id: Uuid,
) -> Result<(), AppError> {
    if claims.role == UserRole::SuperAdmin { return Ok(()); }

    let branch_org: Option<Uuid> = sqlx::query_scalar(
        "SELECT org_id FROM branches WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(branch_id)
    .fetch_optional(pool)
    .await?
    .flatten();

    let branch_org = branch_org
        .ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

    if claims.org_id() != Some(branch_org) {
        return Err(AppError::Forbidden("Branch belongs to a different org".into()));
    }

    if claims.role == UserRole::OrgAdmin { return Ok(()); }

    let assigned: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM user_branch_assignments WHERE user_id = $1 AND branch_id = $2)"
    )
    .bind(claims.user_id())
    .bind(branch_id)
    .fetch_one(pool)
    .await?;

    if !assigned {
        return Err(AppError::Forbidden("Not assigned to this branch".into()));
    }

    Ok(())
}