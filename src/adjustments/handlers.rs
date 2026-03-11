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
pub struct InventoryAdjustment {
    pub id:                Uuid,
    pub branch_id:         Uuid,
    pub inventory_item_id: Uuid,
    pub item_name:         String,
    pub unit:              String,
    pub adjustment_type:   String,
    pub quantity:          sqlx::types::BigDecimal,
    pub note:              Option<String>,
    pub transfer_id:       Option<Uuid>,
    pub adjusted_by:       Uuid,
    pub adjusted_by_name:  String,
    pub created_at:        chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct InventoryTransfer {
    pub id:                    Uuid,
    pub source_branch_id:      Uuid,
    pub source_branch_name:    String,
    pub destination_branch_id: Uuid,
    pub destination_branch_name: String,
    pub inventory_item_id:     Uuid,
    pub item_name:             String,
    pub unit:                  String,
    pub quantity_sent:         sqlx::types::BigDecimal,
    pub quantity_confirmed:    Option<sqlx::types::BigDecimal>,
    pub status:                String,
    pub note:                  Option<String>,
    pub initiated_by:          Uuid,
    pub initiated_by_name:     String,
    pub confirmed_by:          Option<Uuid>,
    pub rejection_reason:      Option<String>,
    pub initiated_at:          chrono::DateTime<chrono::Utc>,
    pub confirmed_at:          Option<chrono::DateTime<chrono::Utc>>,
}

// ── Request types ─────────────────────────────────────────────

#[derive(Deserialize)]
pub struct CreateAdjustmentRequest {
    pub inventory_item_id: Uuid,
    pub adjustment_type:   String, // "add" | "remove"
    pub quantity:          f64,
    pub note:              Option<String>,
}

#[derive(Deserialize)]
pub struct InitiateTransferRequest {
    pub source_branch_id:      Uuid,
    pub destination_branch_id: Uuid,
    pub inventory_item_id:     Uuid,
    pub quantity:              f64,
    pub note:                  Option<String>,
}

#[derive(Deserialize)]
pub struct ConfirmTransferRequest {
    pub quantity_confirmed: f64,   // can be less than sent (partial)
    pub note:               Option<String>,
}

#[derive(Deserialize)]
pub struct RejectTransferRequest {
    pub reason: Option<String>,
}

#[derive(Deserialize)]
pub struct ListTransfersQuery {
    pub direction: Option<String>, // "incoming" | "outgoing" | None = both
}

// ── POST /inventory/branches/:branch_id/adjustments ───────────

pub async fn create_adjustment(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
    body:      web::Json<CreateAdjustmentRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory_adjustments", "create").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    // Validate type
    match body.adjustment_type.as_str() {
        "add" | "remove" => {}
        _ => return Err(AppError::BadRequest(
            "adjustment_type must be 'add' or 'remove'".into(),
        )),
    }

    if body.quantity <= 0.0 {
        return Err(AppError::BadRequest("quantity must be greater than 0".into()));
    }

    // Verify item belongs to this branch
    let item_branch: Option<Uuid> = sqlx::query_scalar(
        "SELECT branch_id FROM inventory_items WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(body.inventory_item_id)
    .fetch_optional(pool.get_ref())
    .await?
    .flatten();

    if item_branch != Some(*branch_id) {
        return Err(AppError::BadRequest(
            "Inventory item does not belong to this branch".into(),
        ));
    }

    // For remove: check sufficient stock
    if body.adjustment_type == "remove" {
        let current: sqlx::types::BigDecimal = sqlx::query_scalar(
            "SELECT current_stock FROM inventory_items WHERE id = $1"
        )
        .bind(body.inventory_item_id)
        .fetch_one(pool.get_ref())
        .await?;

        let qty = sqlx::types::BigDecimal::try_from(body.quantity)
            .map_err(|_| AppError::BadRequest("Invalid quantity".into()))?;

        if current < qty {
            return Err(AppError::BadRequest(format!(
                "Insufficient stock. Current: {}, Requested: {}",
                current, qty
            )));
        }
    }

    // Run in transaction: update stock + log adjustment
    let mut tx = pool.get_ref().begin().await?;

    let stock_delta: f64 = match body.adjustment_type.as_str() {
        "add"    => body.quantity,
        "remove" => -body.quantity,
        _        => unreachable!(),
    };

    sqlx::query(
        "UPDATE inventory_items SET current_stock = current_stock + $1 WHERE id = $2"
    )
    .bind(stock_delta)
    .bind(body.inventory_item_id)
    .execute(&mut *tx)
    .await?;

    let adj_type = match body.adjustment_type.as_str() {
        "add"    => "add",
        "remove" => "remove",
        _        => unreachable!(),
    };

    let adjustment = sqlx::query_as::<_, InventoryAdjustment>(
        r#"
        INSERT INTO inventory_adjustments
            (branch_id, inventory_item_id, type, quantity, note, adjusted_by)
        VALUES ($1, $2, $3::inventory_adjustment_type, $4, $5, $6)
        RETURNING
            id, branch_id, inventory_item_id,
            (SELECT name FROM inventory_items WHERE id = $2) AS item_name,
            (SELECT unit::text FROM inventory_items WHERE id = $2) AS unit,
            type::text AS adjustment_type,
            quantity, note, transfer_id, adjusted_by,
            (SELECT name FROM users WHERE id = $6) AS adjusted_by_name,
            created_at
        "#,
    )
    .bind(*branch_id)
    .bind(body.inventory_item_id)
    .bind(adj_type)
    .bind(body.quantity)
    .bind(&body.note)
    .bind(claims.user_id())
    .fetch_one(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(HttpResponse::Created().json(adjustment))
}

// ── GET /inventory/branches/:branch_id/adjustments ────────────

pub async fn list_adjustments(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory_adjustments", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let rows = sqlx::query_as::<_, InventoryAdjustment>(
        r#"
        SELECT
            a.id, a.branch_id, a.inventory_item_id,
            i.name AS item_name,
            i.unit::text AS unit,
            a.type::text AS adjustment_type,
            a.quantity, a.note, a.transfer_id, a.adjusted_by,
            u.name AS adjusted_by_name,
            a.created_at
        FROM inventory_adjustments a
        JOIN inventory_items i ON i.id = a.inventory_item_id
        JOIN users u ON u.id = a.adjusted_by
        WHERE a.branch_id = $1
        ORDER BY a.created_at DESC
        "#,
    )
    .bind(*branch_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

// ── POST /inventory/transfers ─────────────────────────────────

pub async fn initiate_transfer(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<InitiateTransferRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory_transfers", "create").await?;
    require_branch_access(pool.get_ref(), &claims, body.source_branch_id).await?;

    if body.quantity <= 0.0 {
        return Err(AppError::BadRequest("quantity must be greater than 0".into()));
    }

    if body.source_branch_id == body.destination_branch_id {
        return Err(AppError::BadRequest(
            "Source and destination branches must be different".into(),
        ));
    }

    // Verify item belongs to source branch
    let item_branch: Option<Uuid> = sqlx::query_scalar(
        "SELECT branch_id FROM inventory_items WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(body.inventory_item_id)
    .fetch_optional(pool.get_ref())
    .await?
    .flatten();

    if item_branch != Some(body.source_branch_id) {
        return Err(AppError::BadRequest(
            "Inventory item does not belong to the source branch".into(),
        ));
    }

    // Check sufficient stock on source
    let current: sqlx::types::BigDecimal = sqlx::query_scalar(
        "SELECT current_stock FROM inventory_items WHERE id = $1"
    )
    .bind(body.inventory_item_id)
    .fetch_one(pool.get_ref())
    .await?;

    let qty = sqlx::types::BigDecimal::try_from(body.quantity)
        .map_err(|_| AppError::BadRequest("Invalid quantity".into()))?;

    if current < qty {
        return Err(AppError::BadRequest(format!(
            "Insufficient stock. Current: {}, Requested: {}",
            current, qty
        )));
    }

    let mut tx = pool.get_ref().begin().await?;

    // Deduct from source immediately
    sqlx::query(
        "UPDATE inventory_items SET current_stock = current_stock - $1 WHERE id = $2"
    )
    .bind(body.quantity)
    .bind(body.inventory_item_id)
    .execute(&mut *tx)
    .await?;

    // Create transfer record
    let transfer = sqlx::query_as::<_, InventoryTransfer>(
        r#"
        INSERT INTO inventory_transfers
            (source_branch_id, destination_branch_id, inventory_item_id,
             quantity_sent, note, initiated_by)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING
            id,
            source_branch_id,
            (SELECT name FROM branches WHERE id = $1) AS source_branch_name,
            destination_branch_id,
            (SELECT name FROM branches WHERE id = $2) AS destination_branch_name,
            inventory_item_id,
            (SELECT name FROM inventory_items WHERE id = $3) AS item_name,
            (SELECT unit::text FROM inventory_items WHERE id = $3) AS unit,
            quantity_sent, quantity_confirmed,
            status::text,
            note, initiated_by,
            (SELECT name FROM users WHERE id = $6) AS initiated_by_name,
            confirmed_by, rejection_reason,
            initiated_at, confirmed_at
        "#,
    )
    .bind(body.source_branch_id)
    .bind(body.destination_branch_id)
    .bind(body.inventory_item_id)
    .bind(body.quantity)
    .bind(&body.note)
    .bind(claims.user_id())
    .fetch_one(&mut *tx)
    .await?;

    // Log transfer_out adjustment on source
    sqlx::query(
        r#"
        INSERT INTO inventory_adjustments
            (branch_id, inventory_item_id, type, quantity, note, transfer_id, adjusted_by)
        VALUES ($1, $2, 'transfer_out'::inventory_adjustment_type, $3, $4, $5, $6)
        "#,
    )
    .bind(body.source_branch_id)
    .bind(body.inventory_item_id)
    .bind(body.quantity)
    .bind(format!(
        "Transfer to branch {} — PENDING",
        body.destination_branch_id
    ))
    .bind(transfer.id)
    .bind(claims.user_id())
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(HttpResponse::Created().json(transfer))
}

// ── GET /inventory/branches/:branch_id/transfers ──────────────

pub async fn list_transfers(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
    query:     web::Query<ListTransfersQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory_transfers", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let rows = match query.direction.as_deref() {
        Some("incoming") => sqlx::query_as::<_, InventoryTransfer>(
            r#"
            SELECT
                t.id,
                t.source_branch_id,
                sb.name AS source_branch_name,
                t.destination_branch_id,
                db.name AS destination_branch_name,
                t.inventory_item_id,
                i.name AS item_name,
                i.unit::text AS unit,
                t.quantity_sent, t.quantity_confirmed,
                t.status::text,
                t.note, t.initiated_by,
                u.name AS initiated_by_name,
                t.confirmed_by, t.rejection_reason,
                t.initiated_at, t.confirmed_at
            FROM inventory_transfers t
            JOIN branches sb ON sb.id = t.source_branch_id
            JOIN branches db ON db.id = t.destination_branch_id
            JOIN inventory_items i ON i.id = t.inventory_item_id
            JOIN users u ON u.id = t.initiated_by
            WHERE t.destination_branch_id = $1
            ORDER BY t.initiated_at DESC
            "#,
        )
        .bind(*branch_id)
        .fetch_all(pool.get_ref())
        .await?,

        Some("outgoing") => sqlx::query_as::<_, InventoryTransfer>(
            r#"
            SELECT
                t.id,
                t.source_branch_id,
                sb.name AS source_branch_name,
                t.destination_branch_id,
                db.name AS destination_branch_name,
                t.inventory_item_id,
                i.name AS item_name,
                i.unit::text AS unit,
                t.quantity_sent, t.quantity_confirmed,
                t.status::text,
                t.note, t.initiated_by,
                u.name AS initiated_by_name,
                t.confirmed_by, t.rejection_reason,
                t.initiated_at, t.confirmed_at
            FROM inventory_transfers t
            JOIN branches sb ON sb.id = t.source_branch_id
            JOIN branches db ON db.id = t.destination_branch_id
            JOIN inventory_items i ON i.id = t.inventory_item_id
            JOIN users u ON u.id = t.initiated_by
            WHERE t.source_branch_id = $1
            ORDER BY t.initiated_at DESC
            "#,
        )
        .bind(*branch_id)
        .fetch_all(pool.get_ref())
        .await?,

        _ => sqlx::query_as::<_, InventoryTransfer>(
            r#"
            SELECT
                t.id,
                t.source_branch_id,
                sb.name AS source_branch_name,
                t.destination_branch_id,
                db.name AS destination_branch_name,
                t.inventory_item_id,
                i.name AS item_name,
                i.unit::text AS unit,
                t.quantity_sent, t.quantity_confirmed,
                t.status::text,
                t.note, t.initiated_by,
                u.name AS initiated_by_name,
                t.confirmed_by, t.rejection_reason,
                t.initiated_at, t.confirmed_at
            FROM inventory_transfers t
            JOIN branches sb ON sb.id = t.source_branch_id
            JOIN branches db ON db.id = t.destination_branch_id
            JOIN inventory_items i ON i.id = t.inventory_item_id
            JOIN users u ON u.id = t.initiated_by
            WHERE t.source_branch_id = $1 OR t.destination_branch_id = $1
            ORDER BY t.initiated_at DESC
            "#,
        )
        .bind(*branch_id)
        .fetch_all(pool.get_ref())
        .await?,
    };

    Ok(HttpResponse::Ok().json(rows))
}

// ── GET /inventory/transfers/:transfer_id ─────────────────────

pub async fn get_transfer(
    req:         HttpRequest,
    pool:        web::Data<PgPool>,
    transfer_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory_transfers", "read").await?;

    let transfer = fetch_transfer_or_404(pool.get_ref(), *transfer_id).await?;

    // Must have access to either source or destination branch
    let src_ok = check_branch_access_bool(pool.get_ref(), &claims, transfer.source_branch_id).await?;
    let dst_ok = check_branch_access_bool(pool.get_ref(), &claims, transfer.destination_branch_id).await?;

    if !src_ok && !dst_ok {
        return Err(AppError::Forbidden("No access to this transfer".into()));
    }

    Ok(HttpResponse::Ok().json(transfer))
}

// ── PATCH /inventory/transfers/:transfer_id/confirm ───────────

pub async fn confirm_transfer(
    req:         HttpRequest,
    pool:        web::Data<PgPool>,
    transfer_id: web::Path<Uuid>,
    body:        web::Json<ConfirmTransferRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory_transfers", "update").await?;

    let transfer = fetch_transfer_or_404(pool.get_ref(), *transfer_id).await?;

    // Only destination branch manager can confirm
    require_branch_access(pool.get_ref(), &claims, transfer.destination_branch_id).await?;

    if transfer.status != "pending" {
        return Err(AppError::BadRequest(format!(
            "Transfer is already {}",
            transfer.status
        )));
    }

    if body.quantity_confirmed <= 0.0 {
        return Err(AppError::BadRequest(
            "quantity_confirmed must be greater than 0".into(),
        ));
    }

    let sent: f64 = transfer.quantity_sent.to_string().parse().unwrap_or(0.0);

    if body.quantity_confirmed > sent {
        return Err(AppError::BadRequest(
            "quantity_confirmed cannot exceed quantity_sent".into(),
        ));
    }

    let is_partial = body.quantity_confirmed < sent;
    let new_status = if is_partial { "partial" } else { "completed" };
    let difference = sent - body.quantity_confirmed;

    let mut tx = pool.get_ref().begin().await?;

    // Add confirmed quantity to destination inventory item
    // Find matching item on destination branch by name + unit
    let dest_item_id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT di.id
        FROM inventory_items di
        JOIN inventory_items si ON si.id = $1
        WHERE di.branch_id = $2
          AND di.name = si.name
          AND di.unit = si.unit
          AND di.deleted_at IS NULL
        LIMIT 1
        "#,
    )
    .bind(transfer.inventory_item_id)
    .bind(transfer.destination_branch_id)
    .fetch_optional(&mut *tx)
    .await?
    .flatten();

    let dest_item_id = dest_item_id.ok_or_else(|| {
        AppError::BadRequest(
            "No matching inventory item found on destination branch. \
             Please create the item there first.".into(),
        )
    })?;

    // Add to destination stock
    sqlx::query(
        "UPDATE inventory_items SET current_stock = current_stock + $1 WHERE id = $2"
    )
    .bind(body.quantity_confirmed)
    .bind(dest_item_id)
    .execute(&mut *tx)
    .await?;

    // Log transfer_in on destination
    let transfer_in_note = match &body.note {
        Some(n) => format!("Transfer from branch {} — {} — {}", transfer.source_branch_id, new_status.to_uppercase(), n),
        None    => format!("Transfer from branch {} — {}", transfer.source_branch_id, new_status.to_uppercase()),
    };
    sqlx::query(
        r#"
        INSERT INTO inventory_adjustments
            (branch_id, inventory_item_id, type, quantity, note, transfer_id, adjusted_by)
        VALUES ($1, $2, 'transfer_in'::inventory_adjustment_type, $3, $4, $5, $6)
        "#,
    )
    .bind(transfer.destination_branch_id)
    .bind(dest_item_id)
    .bind(body.quantity_confirmed)
    .bind(&transfer_in_note)
    .bind(transfer.id)
    .bind(claims.user_id())
    .execute(&mut *tx)
    .await?;

    // If partial: return difference to source stock
    if is_partial && difference > 0.0 {
        sqlx::query(
            "UPDATE inventory_items SET current_stock = current_stock + $1 WHERE id = $2"
        )
        .bind(difference)
        .bind(transfer.inventory_item_id)
        .execute(&mut *tx)
        .await?;

        // Log the return as an add adjustment on source
        sqlx::query(
            r#"
            INSERT INTO inventory_adjustments
                (branch_id, inventory_item_id, type, quantity, note, transfer_id, adjusted_by)
            VALUES ($1, $2, 'add'::inventory_adjustment_type, $3, $4, $5, $6)
            "#,
        )
        .bind(transfer.source_branch_id)
        .bind(transfer.inventory_item_id)
        .bind(difference)
        .bind(format!(
            "Partial transfer return from destination branch {} — {} of {} confirmed",
            transfer.destination_branch_id, body.quantity_confirmed, sent
        ))
        .bind(transfer.id)
        .bind(claims.user_id())
        .execute(&mut *tx)
        .await?;
    }

    // Update transfer record — append confirmation note to existing note if provided
    let updated = sqlx::query_as::<_, InventoryTransfer>(
        r#"
        UPDATE inventory_transfers SET
            status             = $2::transfer_status,
            quantity_confirmed = $3,
            confirmed_by       = $4,
            confirmed_at       = NOW(),
            note               = CASE WHEN $5::text IS NOT NULL
                                      THEN COALESCE(note || ' | ', '') || $5
                                      ELSE note
                                 END
        WHERE id = $1
        RETURNING
            id,
            source_branch_id,
            (SELECT name FROM branches WHERE id = source_branch_id) AS source_branch_name,
            destination_branch_id,
            (SELECT name FROM branches WHERE id = destination_branch_id) AS destination_branch_name,
            inventory_item_id,
            (SELECT name FROM inventory_items WHERE id = inventory_item_id) AS item_name,
            (SELECT unit::text FROM inventory_items WHERE id = inventory_item_id) AS unit,
            quantity_sent, quantity_confirmed,
            status::text,
            note, initiated_by,
            (SELECT name FROM users WHERE id = initiated_by) AS initiated_by_name,
            confirmed_by, rejection_reason,
            initiated_at, confirmed_at
        "#,
    )
    .bind(*transfer_id)
    .bind(new_status)
    .bind(body.quantity_confirmed)
    .bind(claims.user_id())
    .bind(&body.note)
    .fetch_one(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(HttpResponse::Ok().json(updated))
}

// ── PATCH /inventory/transfers/:transfer_id/reject ────────────

pub async fn reject_transfer(
    req:         HttpRequest,
    pool:        web::Data<PgPool>,
    transfer_id: web::Path<Uuid>,
    body:        web::Json<RejectTransferRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory_transfers", "update").await?;

    let transfer = fetch_transfer_or_404(pool.get_ref(), *transfer_id).await?;
    require_branch_access(pool.get_ref(), &claims, transfer.destination_branch_id).await?;

    if transfer.status != "pending" {
        return Err(AppError::BadRequest(format!(
            "Transfer is already {}",
            transfer.status
        )));
    }

    let mut tx = pool.get_ref().begin().await?;

    // Restore full quantity to source
    sqlx::query(
        "UPDATE inventory_items SET current_stock = current_stock + $1 WHERE id = $2"
    )
    .bind(&transfer.quantity_sent)
    .bind(transfer.inventory_item_id)
    .execute(&mut *tx)
    .await?;

    // Log restore as add on source
    sqlx::query(
        r#"
        INSERT INTO inventory_adjustments
            (branch_id, inventory_item_id, type, quantity, note, transfer_id, adjusted_by)
        VALUES ($1, $2, 'add'::inventory_adjustment_type, $3, $4, $5, $6)
        "#,
    )
    .bind(transfer.source_branch_id)
    .bind(transfer.inventory_item_id)
    .bind(&transfer.quantity_sent)
    .bind(format!(
        "Transfer rejected by destination branch {} — stock restored",
        transfer.destination_branch_id
    ))
    .bind(transfer.id)
    .bind(claims.user_id())
    .execute(&mut *tx)
    .await?;

    // Update transfer status
    let updated = sqlx::query_as::<_, InventoryTransfer>(
        r#"
        UPDATE inventory_transfers SET
            status           = 'rejected'::transfer_status,
            confirmed_by     = $2,
            confirmed_at     = NOW(),
            rejection_reason = $3
        WHERE id = $1
        RETURNING
            id,
            source_branch_id,
            (SELECT name FROM branches WHERE id = source_branch_id) AS source_branch_name,
            destination_branch_id,
            (SELECT name FROM branches WHERE id = destination_branch_id) AS destination_branch_name,
            inventory_item_id,
            (SELECT name FROM inventory_items WHERE id = inventory_item_id) AS item_name,
            (SELECT unit::text FROM inventory_items WHERE id = inventory_item_id) AS unit,
            quantity_sent, quantity_confirmed,
            status::text,
            note, initiated_by,
            (SELECT name FROM users WHERE id = initiated_by) AS initiated_by_name,
            confirmed_by, rejection_reason,
            initiated_at, confirmed_at
        "#,
    )
    .bind(*transfer_id)
    .bind(claims.user_id())
    .bind(&body.reason)
    .fetch_one(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(HttpResponse::Ok().json(updated))
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_transfer_or_404(pool: &PgPool, transfer_id: Uuid) -> Result<InventoryTransfer, AppError> {
    sqlx::query_as::<_, InventoryTransfer>(
        r#"
        SELECT
            t.id,
            t.source_branch_id,
            sb.name AS source_branch_name,
            t.destination_branch_id,
            db.name AS destination_branch_name,
            t.inventory_item_id,
            i.name AS item_name,
            i.unit::text AS unit,
            t.quantity_sent, t.quantity_confirmed,
            t.status::text,
            t.note, t.initiated_by,
            u.name AS initiated_by_name,
            t.confirmed_by, t.rejection_reason,
            t.initiated_at, t.confirmed_at
        FROM inventory_transfers t
        JOIN branches sb ON sb.id = t.source_branch_id
        JOIN branches db ON db.id = t.destination_branch_id
        JOIN inventory_items i ON i.id = t.inventory_item_id
        JOIN users u ON u.id = t.initiated_by
        WHERE t.id = $1
        "#,
    )
    .bind(transfer_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Transfer not found".into()))
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

    let branch_org = branch_org.ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

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

/// Same as require_branch_access but returns bool instead of error
async fn check_branch_access_bool(
    pool:      &PgPool,
    claims:    &Claims,
    branch_id: Uuid,
) -> Result<bool, AppError> {
    Ok(require_branch_access(pool, claims, branch_id).await.is_ok())
}