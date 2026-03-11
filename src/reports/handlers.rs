use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    auth::jwt::Claims,
    errors::AppError,
    models::UserRole,
    permissions::checker::check_permission,
};

// ── Query params ──────────────────────────────────────────────

#[derive(Deserialize)]
pub struct DateRangeQuery {
    pub from: Option<DateTime<Utc>>,
    pub to:   Option<DateTime<Utc>>,
}

// ── Response types ────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct ShiftSummary {
    pub shift_id:               Uuid,
    pub branch_id:              Uuid,
    pub branch_name:            String,
    pub teller_id:              Uuid,
    pub teller_name:            String,
    pub status:                 String,
    pub opened_at:              DateTime<Utc>,
    pub closed_at:              Option<DateTime<Utc>>,
    // Cash
    pub opening_cash:           i64,
    pub closing_cash_declared:  Option<i64>,
    pub closing_cash_system:    Option<i64>,
    pub cash_discrepancy:       Option<i64>,
    // Orders
    pub total_orders:           i64,
    pub voided_orders:          i64,
    pub total_revenue:          i64,
    pub cash_revenue:           i64,
    pub card_revenue:           i64,
    pub digital_wallet_revenue: i64,
    pub mixed_revenue:          i64,
    pub total_discount:         i64,
    pub total_tax:              i64,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct InventoryDiscrepancy {
    pub inventory_item_id: Uuid,
    pub item_name:         String,
    pub unit:              String,
    pub stock_at_open:     f64,
    pub expected_stock:    f64,
    pub actual_count:      Option<f64>,
    pub discrepancy:       Option<f64>,
    pub notes:             Option<String>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct DeductionLogRow {
    pub id:                Uuid,
    pub order_id:          Option<Uuid>,
    pub order_item_id:     Option<Uuid>,
    pub inventory_item_id: Uuid,
    pub item_name:         String,
    pub unit:              String,
    pub quantity_deducted: f64,
    pub source:            String,
    pub created_at:        DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct CategorySales {
    pub category_id:   Option<Uuid>,
    pub category_name: Option<String>,
    pub item_count:    i64,
    pub quantity_sold: i64,
    pub revenue:       i64,
    pub items:         Vec<ItemSales>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct ItemSales {
    pub menu_item_id:  Uuid,
    pub item_name:     String,
    pub quantity_sold: i64,
    pub revenue:       i64,
}

#[derive(Debug, Serialize)]
pub struct BranchSalesReport {
    pub branch_id:          Uuid,
    pub branch_name:        String,
    pub from:               Option<DateTime<Utc>>,
    pub to:                 Option<DateTime<Utc>>,
    pub total_orders:       i64,
    pub voided_orders:      i64,
    pub subtotal:           i64,
    pub total_discount:     i64,
    pub total_tax:          i64,
    pub total_revenue:      i64,
    // Payment breakdown
    pub cash_revenue:           i64,
    pub card_revenue:           i64,
    pub digital_wallet_revenue: i64,
    pub mixed_revenue:          i64,
    // Top items
    pub top_items:          Vec<ItemSales>,
    // Per category
    pub by_category:        Vec<CategorySales>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct StockRow {
    pub inventory_item_id: Uuid,
    pub item_name:         String,
    pub unit:              String,
    pub current_stock:     f64,
    pub reorder_threshold: f64,
    pub cost_per_unit:     Option<f64>,
    pub below_reorder:     bool,
    pub is_active:         bool,
}

#[derive(Debug, Serialize)]
pub struct BranchStockReport {
    pub branch_id:   Uuid,
    pub branch_name: String,
    pub items:       Vec<StockRow>,
}

// ── GET /reports/shifts/:id/summary ──────────────────────────

pub async fn shift_summary(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    shift_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "read").await?;

    let branch_id = require_shift_branch_access(pool.get_ref(), &claims, *shift_id).await?;
    let _ = branch_id;

    let summary = sqlx::query_as::<_, ShiftSummary>(
        r#"
        SELECT
            s.id                                        AS shift_id,
            s.branch_id,
            b.name                                      AS branch_name,
            s.teller_id,
            u.name                                      AS teller_name,
            s.status::text,
            s.created_at                                AS opened_at,
            s.closed_at,
            s.opening_cash::bigint,
            s.closing_cash_declared::bigint,
            s.closing_cash_system::bigint,
            s.cash_discrepancy::bigint,
            -- Order counts
            COUNT(o.id) FILTER (WHERE o.status != 'voided')     AS total_orders,
            COUNT(o.id) FILTER (WHERE o.status = 'voided')      AS voided_orders,
            -- Revenue (exclude voided)
            COALESCE(SUM(o.total_amount)  FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_revenue,
            COALESCE(SUM(o.total_amount)  FILTER (WHERE o.status != 'voided' AND o.payment_method = 'cash'),           0)::bigint AS cash_revenue,
            COALESCE(SUM(o.total_amount)  FILTER (WHERE o.status != 'voided' AND o.payment_method = 'card'),           0)::bigint AS card_revenue,
            COALESCE(SUM(o.total_amount)  FILTER (WHERE o.status != 'voided' AND o.payment_method = 'digital_wallet'), 0)::bigint AS digital_wallet_revenue,
            COALESCE(SUM(o.total_amount)  FILTER (WHERE o.status != 'voided' AND o.payment_method = 'mixed'),          0)::bigint AS mixed_revenue,
            COALESCE(SUM(o.discount_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_discount,
            COALESCE(SUM(o.tax_amount)    FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_tax
        FROM shifts s
        JOIN branches b ON b.id = s.branch_id
        JOIN users    u ON u.id = s.teller_id
        LEFT JOIN orders o ON o.shift_id = s.id
        WHERE s.id = $1
        GROUP BY s.id, b.name, u.name
        "#,
    )
    .bind(*shift_id)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Shift not found".into()))?;

    Ok(HttpResponse::Ok().json(summary))
}

// ── GET /reports/shifts/:id/inventory ────────────────────────

pub async fn shift_inventory_discrepancies(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    shift_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shift_counts", "read").await?;

    require_shift_branch_access(pool.get_ref(), &claims, *shift_id).await?;

    // Sum deductions per inventory item for this shift
    // expected = snapshot - deductions
    // actual   = shift_inventory_counts
    let rows = sqlx::query_as::<_, InventoryDiscrepancy>(
        r#"
        SELECT
            ii.id                                           AS inventory_item_id,
            ii.name                                         AS item_name,
            ii.unit::text                                   AS unit,
            snap.quantity_at_open::float8                   AS stock_at_open,
            GREATEST(0,
                snap.quantity_at_open::float8
                - COALESCE(deduct.total_deducted, 0)
            )                                               AS expected_stock,
            cnt.actual_count::float8,
            cnt.discrepancy::float8,
            cnt.notes
        FROM shift_inventory_snapshots snap
        JOIN inventory_items ii ON ii.id = snap.inventory_item_id
        LEFT JOIN (
            SELECT inventory_item_id, SUM(quantity_deducted) AS total_deducted
            FROM inventory_deduction_logs
            WHERE order_id IN (SELECT id FROM orders WHERE shift_id = $1)
            GROUP BY inventory_item_id
        ) deduct ON deduct.inventory_item_id = snap.inventory_item_id
        LEFT JOIN shift_inventory_counts cnt
               ON cnt.shift_id = snap.shift_id
              AND cnt.inventory_item_id = snap.inventory_item_id
        WHERE snap.shift_id = $1
        ORDER BY ii.name ASC
        "#,
    )
    .bind(*shift_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

// ── GET /reports/shifts/:id/deductions ───────────────────────

pub async fn shift_deductions(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    shift_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory", "read").await?;

    require_shift_branch_access(pool.get_ref(), &claims, *shift_id).await?;

    let rows = sqlx::query_as::<_, DeductionLogRow>(
        r#"
        SELECT
            dl.id,
            dl.order_id,
            dl.order_item_id,
            dl.inventory_item_id,
            ii.name         AS item_name,
            ii.unit::text   AS unit,
            dl.quantity_deducted::float8,
            dl.source,
            dl.created_at
        FROM inventory_deduction_logs dl
        JOIN inventory_items ii ON ii.id = dl.inventory_item_id
        WHERE dl.order_id IN (
            SELECT id FROM orders WHERE shift_id = $1
        )
        ORDER BY dl.created_at ASC
        "#,
    )
    .bind(*shift_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

// ── GET /reports/branches/:id/sales ──────────────────────────

pub async fn branch_sales(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
    query:     web::Query<DateRangeQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let branch_name: String = sqlx::query_scalar(
        "SELECT name FROM branches WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(*branch_id)
    .fetch_optional(pool.get_ref())
    .await?
    .flatten()
    .ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

    // ── Totals ────────────────────────────────────────────────
    struct Totals {
        total_orders:           i64,
        voided_orders:          i64,
        subtotal:               i64,
        total_discount:         i64,
        total_tax:              i64,
        total_revenue:          i64,
        cash_revenue:           i64,
        card_revenue:           i64,
        digital_wallet_revenue: i64,
        mixed_revenue:          i64,
    }

    let totals: (i64, i64, i64, i64, i64, i64, i64, i64, i64, i64) = sqlx::query_as(
        r#"
        SELECT
            COUNT(*)        FILTER (WHERE status != 'voided'),
            COUNT(*)        FILTER (WHERE status = 'voided'),
            COALESCE(SUM(subtotal)        FILTER (WHERE status != 'voided'), 0),
            COALESCE(SUM(discount_amount) FILTER (WHERE status != 'voided'), 0),
            COALESCE(SUM(tax_amount)      FILTER (WHERE status != 'voided'), 0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided'), 0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'cash'),           0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'card'),           0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'digital_wallet'), 0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'mixed'),          0)
        FROM orders
        WHERE branch_id = $1
          AND ($2::timestamptz IS NULL OR created_at >= $2)
          AND ($3::timestamptz IS NULL OR created_at <= $3)
        "#,
    )
    .bind(*branch_id)
    .bind(query.from)
    .bind(query.to)
    .fetch_one(pool.get_ref())
    .await?;

    let t = Totals {
        total_orders:           totals.0,
        voided_orders:          totals.1,
        subtotal:               totals.2,
        total_discount:         totals.3,
        total_tax:              totals.4,
        total_revenue:          totals.5,
        cash_revenue:           totals.6,
        card_revenue:           totals.7,
        digital_wallet_revenue: totals.8,
        mixed_revenue:          totals.9,
    };

    // ── Top items (top 20 by revenue) ─────────────────────────
    let top_items = sqlx::query_as::<_, ItemSales>(
        r#"
        SELECT
            oi.menu_item_id,
            oi.item_name,
            SUM(oi.quantity)::bigint   AS quantity_sold,
            SUM(oi.line_total)::bigint AS revenue
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE o.branch_id = $1
          AND o.status != 'voided'
          AND ($2::timestamptz IS NULL OR o.created_at >= $2)
          AND ($3::timestamptz IS NULL OR o.created_at <= $3)
        GROUP BY oi.menu_item_id, oi.item_name
        ORDER BY revenue DESC
        LIMIT 20
        "#,
    )
    .bind(*branch_id)
    .bind(query.from)
    .bind(query.to)
    .fetch_all(pool.get_ref())
    .await?;

    // ── Per category ──────────────────────────────────────────
    // Fetch all categories present in this date range with their items
    #[derive(sqlx::FromRow)]
    struct CategoryItemRow {
        category_id:   Option<Uuid>,
        category_name: Option<String>,
        menu_item_id:  Uuid,
        item_name:     String,
        quantity_sold: i64,
        revenue:       i64,
    }

    let cat_rows = sqlx::query_as::<_, CategoryItemRow>(
        r#"
        SELECT
            m.category_id,
            c.name                     AS category_name,
            oi.menu_item_id,
            oi.item_name,
            SUM(oi.quantity)::bigint   AS quantity_sold,
            SUM(oi.line_total)::bigint AS revenue
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        JOIN menu_items m ON m.id = oi.menu_item_id
        LEFT JOIN categories c ON c.id = m.category_id
        WHERE o.branch_id = $1
          AND o.status != 'voided'
          AND ($2::timestamptz IS NULL OR o.created_at >= $2)
          AND ($3::timestamptz IS NULL OR o.created_at <= $3)
        GROUP BY m.category_id, c.name, oi.menu_item_id, oi.item_name
        ORDER BY c.name NULLS LAST, revenue DESC
        "#,
    )
    .bind(*branch_id)
    .bind(query.from)
    .bind(query.to)
    .fetch_all(pool.get_ref())
    .await?;

    // Group into Vec<CategorySales>
    let mut by_category: Vec<CategorySales> = Vec::new();
    for row in cat_rows {
        let existing = by_category.iter_mut().find(|c| c.category_id == row.category_id);
        let item = ItemSales {
            menu_item_id:  row.menu_item_id,
            item_name:     row.item_name,
            quantity_sold: row.quantity_sold,
            revenue:       row.revenue,
        };
        match existing {
            Some(cat) => {
                cat.item_count  += 1;
                cat.quantity_sold += item.quantity_sold;
                cat.revenue      += item.revenue;
                cat.items.push(item);
            }
            None => {
                by_category.push(CategorySales {
                    category_id:   row.category_id,
                    category_name: row.category_name,
                    item_count:    1,
                    quantity_sold: item.quantity_sold,
                    revenue:       item.revenue,
                    items:         vec![item],
                });
            }
        }
    }

    Ok(HttpResponse::Ok().json(BranchSalesReport {
        branch_id:          *branch_id,
        branch_name,
        from:               query.from,
        to:                 query.to,
        total_orders:       t.total_orders,
        voided_orders:      t.voided_orders,
        subtotal:           t.subtotal,
        total_discount:     t.total_discount,
        total_tax:          t.total_tax,
        total_revenue:      t.total_revenue,
        cash_revenue:       t.cash_revenue,
        card_revenue:       t.card_revenue,
        digital_wallet_revenue: t.digital_wallet_revenue,
        mixed_revenue:      t.mixed_revenue,
        top_items,
        by_category,
    }))
}

// ── GET /reports/branches/:id/stock ──────────────────────────

pub async fn branch_stock(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let branch_name: String = sqlx::query_scalar(
        "SELECT name FROM branches WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(*branch_id)
    .fetch_optional(pool.get_ref())
    .await?
    .flatten()
    .ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

    let items = sqlx::query_as::<_, StockRow>(
        r#"
        SELECT
            id                                              AS inventory_item_id,
            name                                            AS item_name,
            unit::text,
            current_stock::float8,
            reorder_threshold::float8,
            cost_per_unit::float8,
            (current_stock <= reorder_threshold)            AS below_reorder,
            is_active
        FROM inventory_items
        WHERE branch_id = $1 AND deleted_at IS NULL
        ORDER BY (current_stock <= reorder_threshold) DESC, name ASC
        "#,
    )
    .bind(*branch_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(BranchStockReport {
        branch_id:   *branch_id,
        branch_name,
        items,
    }))
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

/// Returns the branch_id of the shift after verifying access
async fn require_shift_branch_access(
    pool:     &PgPool,
    claims:   &Claims,
    shift_id: Uuid,
) -> Result<Uuid, AppError> {
    let branch_id: Option<Uuid> = sqlx::query_scalar(
        "SELECT branch_id FROM shifts WHERE id = $1"
    )
    .bind(shift_id)
    .fetch_optional(pool)
    .await?
    .flatten();

    let branch_id = branch_id
        .ok_or_else(|| AppError::NotFound("Shift not found".into()))?;

    require_branch_access(pool, claims, branch_id).await?;
    Ok(branch_id)
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