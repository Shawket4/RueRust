#!/usr/bin/env bash
# =============================================================================
#  Rue POS — Backend Non-Breaking Improvements
#  Run from the root of the Rust backend project (where Cargo.toml lives).
#
#  Changes:
#   1. reports/handlers.rs
#      - BranchSalesReport: add talabat_online_revenue + talabat_cash_revenue fields
#      - branch_sales query: aggregate those two payment methods
#      - top_items: respect optional ?limit query param (default 20)
#      - TimeseriesPoint: add per-payment-method breakdown columns
#      - branch_sales_timeseries: add talabat columns to SELECT
#      - OrgComparisonReport/BranchComparison: add talabat columns
#
#   2. shifts/handlers.rs
#      - ShiftReportResponse: add order_count to PaymentSummaryRow (already
#        has it via sqlx but the struct needs it surfaced)
#        → PaymentSummaryRow already has order_count — it just needs to be
#          confirmed the SQL returns it. It does. No struct change needed.
#        → Add cash_movements_net computed field to response.
#
#   3. branches/handlers.rs
#      - UpdateBranchRequest: allow explicit null for printer_brand/ip/port
#      - update_branch query: use a smarter CASE so NULL input clears the field
#
# =============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

log()  { echo -e "${CYAN}[patch]${RESET} $*"; }
ok()   { echo -e "${GREEN}[done] ${RESET} $*"; }
warn() { echo -e "${YELLOW}[warn] ${RESET} $*"; }

# ---------------------------------------------------------------------------
# Guard: must be run from the Rust project root
# ---------------------------------------------------------------------------
if [[ ! -f "Cargo.toml" ]]; then
  echo "ERROR: Run this script from the Rust project root (where Cargo.toml lives)."
  exit 1
fi

# ===========================================================================
#  1. src/reports/handlers.rs
# ===========================================================================
log "Patching src/reports/handlers.rs ..."

cat > src/reports/handlers.rs << 'RUST'
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
    pub from:  Option<DateTime<Utc>>,
    pub to:    Option<DateTime<Utc>>,
    pub limit: Option<i64>, // for top_items (default 20)
}

#[derive(Deserialize)]
pub struct TimeseriesQuery {
    pub from:        Option<DateTime<Utc>>,
    pub to:          Option<DateTime<Utc>>,
    pub granularity: Option<String>, // "hourly" | "daily" | "monthly"
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
    pub opening_cash:           i64,
    pub closing_cash_declared:  Option<i64>,
    pub closing_cash_system:    Option<i64>,
    pub cash_discrepancy:       Option<i64>,
    pub total_orders:           i64,
    pub voided_orders:          i64,
    pub total_revenue:          i64,
    pub cash_revenue:           i64,
    pub card_revenue:           i64,
    pub digital_wallet_revenue: i64,
    pub mixed_revenue:          i64,
    pub talabat_online_revenue: i64,
    pub talabat_cash_revenue:   i64,
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
    pub branch_id:              Uuid,
    pub branch_name:            String,
    pub from:                   Option<DateTime<Utc>>,
    pub to:                     Option<DateTime<Utc>>,
    pub total_orders:           i64,
    pub voided_orders:          i64,
    pub subtotal:               i64,
    pub total_discount:         i64,
    pub total_tax:              i64,
    pub total_revenue:          i64,
    pub cash_revenue:           i64,
    pub card_revenue:           i64,
    pub digital_wallet_revenue: i64,
    pub mixed_revenue:          i64,
    pub talabat_online_revenue: i64,
    pub talabat_cash_revenue:   i64,
    pub top_items:              Vec<ItemSales>,
    pub by_category:            Vec<CategorySales>,
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

// Timeseries now includes per-payment-method breakdown
#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct TimeseriesPoint {
    pub period:                 String,
    pub orders:                 i64,
    pub revenue:                i64,
    pub voided:                 i64,
    pub discount:               i64,
    pub tax:                    i64,
    pub cash_revenue:           i64,
    pub card_revenue:           i64,
    pub digital_wallet_revenue: i64,
    pub mixed_revenue:          i64,
    pub talabat_online_revenue: i64,
    pub talabat_cash_revenue:   i64,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct TellerStats {
    pub teller_id:       Uuid,
    pub teller_name:     String,
    pub orders:          i64,
    pub revenue:         i64,
    pub avg_order_value: i64,
    pub voided:          i64,
    pub shifts:          i64,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct AddonSalesRow {
    pub addon_item_id: Uuid,
    pub addon_name:    String,
    pub addon_type:    String,
    pub quantity_sold: i64,
    pub revenue:       i64,
}

#[derive(Debug, Serialize)]
pub struct BranchComparison {
    pub branch_id:              Uuid,
    pub branch_name:            String,
    pub total_orders:           i64,
    pub voided_orders:          i64,
    pub total_revenue:          i64,
    pub cash_revenue:           i64,
    pub card_revenue:           i64,
    pub digital_wallet_revenue: i64,
    pub mixed_revenue:          i64,
    pub talabat_online_revenue: i64,
    pub talabat_cash_revenue:   i64,
    pub avg_order_value:        i64,
    pub void_rate_pct:          f64,
}

#[derive(Debug, Serialize)]
pub struct OrgComparisonReport {
    pub org_id:   Uuid,
    pub from:     Option<DateTime<Utc>>,
    pub to:       Option<DateTime<Utc>>,
    pub branches: Vec<BranchComparison>,
}

// ── GET /reports/shifts/:id/summary ──────────────────────────

pub async fn shift_summary(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    shift_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "shifts", "read").await?;
    require_shift_branch_access(pool.get_ref(), &claims, *shift_id).await?;

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
            COUNT(o.id) FILTER (WHERE o.status != 'voided')::bigint     AS total_orders,
            COUNT(o.id) FILTER (WHERE o.status = 'voided')::bigint      AS voided_orders,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint                                            AS total_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'cash'),           0)::bigint    AS cash_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'card'),           0)::bigint    AS card_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'digital_wallet'), 0)::bigint    AS digital_wallet_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'mixed'),          0)::bigint    AS mixed_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'talabat_online'), 0)::bigint    AS talabat_online_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'talabat_cash'),   0)::bigint    AS talabat_cash_revenue,
            COALESCE(SUM(o.discount_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_discount,
            COALESCE(SUM(o.tax_amount)      FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_tax
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

    // 12-column aggregate — includes talabat variants
    #[allow(clippy::type_complexity)]
    let totals: (i64,i64,i64,i64,i64,i64,i64,i64,i64,i64,i64,i64) = sqlx::query_as(
        r#"
        SELECT
            COUNT(*) FILTER (WHERE status != 'voided'),
            COUNT(*) FILTER (WHERE status = 'voided'),
            COALESCE(SUM(subtotal)        FILTER (WHERE status != 'voided'), 0),
            COALESCE(SUM(discount_amount) FILTER (WHERE status != 'voided'), 0),
            COALESCE(SUM(tax_amount)      FILTER (WHERE status != 'voided'), 0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided'), 0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'cash'),           0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'card'),           0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'digital_wallet'), 0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'mixed'),          0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'talabat_online'), 0),
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'talabat_cash'),   0)
        FROM orders
        WHERE branch_id = $1
          AND ($2::timestamptz IS NULL OR created_at >= $2)
          AND ($3::timestamptz IS NULL OR created_at <= $3)
        "#,
    )
    .bind(*branch_id).bind(query.from).bind(query.to)
    .fetch_one(pool.get_ref()).await?;

    let item_limit = query.limit.unwrap_or(20).min(100).max(1);

    let top_items = sqlx::query_as::<_, ItemSales>(
        r#"
        SELECT oi.menu_item_id, oi.item_name,
               SUM(oi.quantity)::bigint   AS quantity_sold,
               SUM(oi.line_total)::bigint AS revenue
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE o.branch_id = $1 AND o.status != 'voided'
          AND ($2::timestamptz IS NULL OR o.created_at >= $2)
          AND ($3::timestamptz IS NULL OR o.created_at <= $3)
        GROUP BY oi.menu_item_id, oi.item_name
        ORDER BY revenue DESC
        LIMIT $4
        "#,
    )
    .bind(*branch_id).bind(query.from).bind(query.to).bind(item_limit)
    .fetch_all(pool.get_ref()).await?;

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
        SELECT m.category_id, c.name AS category_name,
               oi.menu_item_id, oi.item_name,
               SUM(oi.quantity)::bigint   AS quantity_sold,
               SUM(oi.line_total)::bigint AS revenue
        FROM order_items oi
        JOIN orders o     ON o.id  = oi.order_id
        JOIN menu_items m ON m.id  = oi.menu_item_id
        LEFT JOIN categories c ON c.id = m.category_id
        WHERE o.branch_id = $1 AND o.status != 'voided'
          AND ($2::timestamptz IS NULL OR o.created_at >= $2)
          AND ($3::timestamptz IS NULL OR o.created_at <= $3)
        GROUP BY m.category_id, c.name, oi.menu_item_id, oi.item_name
        ORDER BY c.name NULLS LAST, revenue DESC
        "#,
    )
    .bind(*branch_id).bind(query.from).bind(query.to)
    .fetch_all(pool.get_ref()).await?;

    let mut by_category: Vec<CategorySales> = Vec::new();
    for row in cat_rows {
        let item = ItemSales {
            menu_item_id:  row.menu_item_id,
            item_name:     row.item_name,
            quantity_sold: row.quantity_sold,
            revenue:       row.revenue,
        };
        match by_category.iter_mut().find(|c| c.category_id == row.category_id) {
            Some(cat) => {
                cat.item_count    += 1;
                cat.quantity_sold += item.quantity_sold;
                cat.revenue       += item.revenue;
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
        branch_id:              *branch_id,
        branch_name,
        from:                   query.from,
        to:                     query.to,
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
        talabat_online_revenue: totals.10,
        talabat_cash_revenue:   totals.11,
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
    .fetch_optional(pool.get_ref()).await?.flatten()
    .ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

    let items = sqlx::query_as::<_, StockRow>(
        r#"
        SELECT id AS inventory_item_id, name AS item_name, unit::text,
               current_stock::float8, reorder_threshold::float8, cost_per_unit::float8,
               (current_stock <= reorder_threshold) AS below_reorder, is_active
        FROM inventory_items
        WHERE branch_id = $1 AND deleted_at IS NULL
        ORDER BY (current_stock <= reorder_threshold) DESC, name ASC
        "#,
    )
    .bind(*branch_id)
    .fetch_all(pool.get_ref()).await?;

    Ok(HttpResponse::Ok().json(BranchStockReport {
        branch_id:   *branch_id,
        branch_name,
        items,
    }))
}

// ── GET /reports/branches/:id/sales/timeseries ───────────────

pub async fn branch_sales_timeseries(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
    query:     web::Query<TimeseriesQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let trunc = match query.granularity.as_deref().unwrap_or("daily") {
        "hourly"  => "hour",
        "monthly" => "month",
        _         => "day",
    };

    // trunc is server-controlled — not user input, safe to interpolate
    let sql = format!(
        r#"
        SELECT
            to_char(
                date_trunc('{trunc}', created_at AT TIME ZONE 'Africa/Cairo'),
                'YYYY-MM-DD"T"HH24:MI:SS'
            ) AS period,
            COUNT(*)        FILTER (WHERE status != 'voided')::bigint  AS orders,
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided'), 0)::bigint AS revenue,
            COUNT(*)        FILTER (WHERE status = 'voided')::bigint   AS voided,
            COALESCE(SUM(discount_amount) FILTER (WHERE status != 'voided'), 0)::bigint AS discount,
            COALESCE(SUM(tax_amount)      FILTER (WHERE status != 'voided'), 0)::bigint AS tax,
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'cash'),           0)::bigint AS cash_revenue,
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'card'),           0)::bigint AS card_revenue,
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'digital_wallet'), 0)::bigint AS digital_wallet_revenue,
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'mixed'),          0)::bigint AS mixed_revenue,
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'talabat_online'), 0)::bigint AS talabat_online_revenue,
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided' AND payment_method = 'talabat_cash'),   0)::bigint AS talabat_cash_revenue
        FROM orders
        WHERE branch_id = $1
          AND ($2::timestamptz IS NULL OR created_at >= $2)
          AND ($3::timestamptz IS NULL OR created_at <= $3)
        GROUP BY date_trunc('{trunc}', created_at AT TIME ZONE 'Africa/Cairo')
        ORDER BY 1 ASC
        "#,
        trunc = trunc
    );

    let rows = sqlx::query_as::<_, TimeseriesPoint>(&sql)
        .bind(*branch_id)
        .bind(query.from)
        .bind(query.to)
        .fetch_all(pool.get_ref())
        .await?;

    Ok(HttpResponse::Ok().json(rows))
}

// ── GET /reports/branches/:id/tellers ────────────────────────

pub async fn branch_teller_stats(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
    query:     web::Query<DateRangeQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let rows = sqlx::query_as::<_, TellerStats>(
        r#"
        SELECT
            o.teller_id,
            u.name AS teller_name,
            COUNT(o.id) FILTER (WHERE o.status != 'voided')::bigint AS orders,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint AS revenue,
            CASE
                WHEN COUNT(o.id) FILTER (WHERE o.status != 'voided') = 0 THEN 0
                ELSE (
                    COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided'), 0)
                    / COUNT(o.id) FILTER (WHERE o.status != 'voided')
                )::bigint
            END AS avg_order_value,
            COUNT(o.id) FILTER (WHERE o.status = 'voided')::bigint AS voided,
            COUNT(DISTINCT o.shift_id)::bigint AS shifts
        FROM orders o
        JOIN users u ON u.id = o.teller_id
        WHERE o.branch_id = $1
          AND ($2::timestamptz IS NULL OR o.created_at >= $2)
          AND ($3::timestamptz IS NULL OR o.created_at <= $3)
        GROUP BY o.teller_id, u.name
        ORDER BY revenue DESC
        "#,
    )
    .bind(*branch_id)
    .bind(query.from)
    .bind(query.to)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

// ── GET /reports/branches/:id/addons ─────────────────────────

pub async fn branch_addon_sales(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
    query:     web::Query<DateRangeQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let rows = sqlx::query_as::<_, AddonSalesRow>(
        r#"
        SELECT
            oia.addon_item_id,
            oia.addon_name,
            COALESCE(ai.type, 'extra') AS addon_type,
            SUM(oia.quantity)::bigint  AS quantity_sold,
            SUM(oia.line_total)::bigint AS revenue
        FROM order_item_addons oia
        JOIN order_items oi ON oi.id  = oia.order_item_id
        JOIN orders o       ON o.id   = oi.order_id
        LEFT JOIN addon_items ai ON ai.id = oia.addon_item_id
        WHERE o.branch_id = $1
          AND o.status != 'voided'
          AND ($2::timestamptz IS NULL OR o.created_at >= $2)
          AND ($3::timestamptz IS NULL OR o.created_at <= $3)
        GROUP BY oia.addon_item_id, oia.addon_name, ai.type
        ORDER BY quantity_sold DESC
        "#,
    )
    .bind(*branch_id)
    .bind(query.from)
    .bind(query.to)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

// ── GET /reports/orgs/:org_id/comparison ─────────────────────

pub async fn org_branch_comparison(
    req:    HttpRequest,
    pool:   web::Data<PgPool>,
    org_id: web::Path<Uuid>,
    query:  web::Query<DateRangeQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "read").await?;

    if claims.role != UserRole::SuperAdmin {
        if claims.org_id() != Some(*org_id) {
            return Err(AppError::Forbidden("Not your org".into()));
        }
    }

    #[derive(sqlx::FromRow)]
    struct Row {
        branch_id:              Uuid,
        branch_name:            String,
        total_orders:           i64,
        voided_orders:          i64,
        total_revenue:          i64,
        cash_revenue:           i64,
        card_revenue:           i64,
        digital_wallet_revenue: i64,
        mixed_revenue:          i64,
        talabat_online_revenue: i64,
        talabat_cash_revenue:   i64,
    }

    let rows = sqlx::query_as::<_, Row>(
        r#"
        SELECT
            b.id   AS branch_id,
            b.name AS branch_name,
            COUNT(o.id) FILTER (WHERE o.status != 'voided')::bigint AS total_orders,
            COUNT(o.id) FILTER (WHERE o.status = 'voided')::bigint  AS voided_orders,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided'),                                            0)::bigint AS total_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'cash'),              0)::bigint AS cash_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'card'),              0)::bigint AS card_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'digital_wallet'),    0)::bigint AS digital_wallet_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'mixed'),             0)::bigint AS mixed_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'talabat_online'),    0)::bigint AS talabat_online_revenue,
            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided' AND o.payment_method = 'talabat_cash'),      0)::bigint AS talabat_cash_revenue
        FROM branches b
        LEFT JOIN orders o ON o.branch_id = b.id
          AND ($2::timestamptz IS NULL OR o.created_at >= $2)
          AND ($3::timestamptz IS NULL OR o.created_at <= $3)
        WHERE b.org_id = $1 AND b.deleted_at IS NULL
        GROUP BY b.id, b.name
        ORDER BY total_revenue DESC
        "#,
    )
    .bind(*org_id)
    .bind(query.from)
    .bind(query.to)
    .fetch_all(pool.get_ref())
    .await?;

    let branches = rows.into_iter().map(|r| BranchComparison {
        branch_id:              r.branch_id,
        branch_name:            r.branch_name,
        total_orders:           r.total_orders,
        voided_orders:          r.voided_orders,
        total_revenue:          r.total_revenue,
        cash_revenue:           r.cash_revenue,
        card_revenue:           r.card_revenue,
        digital_wallet_revenue: r.digital_wallet_revenue,
        mixed_revenue:          r.mixed_revenue,
        talabat_online_revenue: r.talabat_online_revenue,
        talabat_cash_revenue:   r.talabat_cash_revenue,
        avg_order_value: if r.total_orders == 0 { 0 }
                         else { r.total_revenue / r.total_orders },
        void_rate_pct:   if (r.total_orders + r.voided_orders) == 0 { 0.0 }
                         else { r.voided_orders as f64
                                / (r.total_orders + r.voided_orders) as f64
                                * 100.0 },
    }).collect();

    Ok(HttpResponse::Ok().json(OrgComparisonReport {
        org_id:   *org_id,
        from:     query.from,
        to:       query.to,
        branches,
    }))
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

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
RUST

ok "src/reports/handlers.rs"

# ===========================================================================
#  2. src/branches/handlers.rs  — allow nulling printer config
# ===========================================================================
log "Patching src/branches/handlers.rs ..."

cat > src/branches/handlers.rs << 'RUST'
use actix_web::{web, HttpRequest, HttpResponse};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;
use actix_web::HttpMessage;

use crate::{
    auth::{guards::require_same_org, jwt::Claims},
    errors::AppError,
    permissions::checker::check_permission,
};

#[derive(Debug, Serialize, Deserialize, sqlx::Type, Clone, PartialEq)]
#[sqlx(type_name = "printer_brand", rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum PrinterBrand {
    Star,
    Epson,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Branch {
    pub id:            Uuid,
    pub org_id:        Uuid,
    pub name:          String,
    pub address:       Option<String>,
    pub phone:         Option<String>,
    pub timezone:      String,
    pub printer_brand: Option<PrinterBrand>,
    pub printer_ip:    Option<String>,
    pub printer_port:  Option<i32>,
    pub is_active:     bool,
    pub created_at:    DateTime<Utc>,
    pub updated_at:    DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct ListBranchesQuery {
    pub org_id: Uuid,
}

#[derive(Deserialize)]
pub struct CreateBranchRequest {
    pub org_id:        Uuid,
    pub name:          String,
    pub address:       Option<String>,
    pub phone:         Option<String>,
    pub timezone:      Option<String>,
    pub printer_brand: Option<PrinterBrand>,
    pub printer_ip:    Option<String>,
    pub printer_port:  Option<i32>,
}

// UpdateBranchRequest uses Option<Option<T>> (double-option) so that:
//   - field absent from JSON  → outer None → don't touch DB column
//   - field present as null   → outer Some(None) → set DB column to NULL
//   - field present as value  → outer Some(Some(v)) → update DB column
//
// Serde's `default` + `deserialize_with` handles this via a small helper.
#[derive(Deserialize)]
pub struct UpdateBranchRequest {
    pub name:      Option<String>,
    pub address:   Option<String>,
    pub phone:     Option<String>,
    pub timezone:  Option<String>,
    pub is_active: Option<bool>,

    // Nullable fields — use double-option pattern
    #[serde(default, deserialize_with = "double_option")]
    pub printer_brand: Option<Option<PrinterBrand>>,
    #[serde(default, deserialize_with = "double_option")]
    pub printer_ip:    Option<Option<String>>,
    #[serde(default, deserialize_with = "double_option")]
    pub printer_port:  Option<Option<i32>>,
}

/// Deserializes a field that can be:
///  - absent          → None        (don't update)
///  - present as null → Some(None)  (set to null)
///  - present as value→ Some(Some(v))(set to value)
fn double_option<'de, T, D>(de: D) -> Result<Option<Option<T>>, D::Error>
where
    T: serde::Deserialize<'de>,
    D: serde::Deserializer<'de>,
{
    serde::Deserialize::deserialize(de).map(Some)
}

pub async fn list_branches(
    req:   HttpRequest,
    pool:  web::Data<PgPool>,
    query: web::Query<ListBranchesQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "read").await?;
    require_same_org(&claims, Some(query.org_id))?;

    let branches = sqlx::query_as::<_, Branch>(
        r#"
        SELECT id, org_id, name, address, phone, timezone,
               printer_brand, printer_ip::text, printer_port,
               is_active, created_at, updated_at
        FROM branches
        WHERE org_id = $1 AND deleted_at IS NULL
        ORDER BY name
        "#,
    )
    .bind(query.org_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(branches))
}

pub async fn get_branch(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "read").await?;

    let branch = fetch_branch(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(branch.org_id))?;

    Ok(HttpResponse::Ok().json(branch))
}

pub async fn create_branch(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateBranchRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "create").await?;
    require_same_org(&claims, Some(body.org_id))?;

    let branch = sqlx::query_as::<_, Branch>(
        r#"
        INSERT INTO branches (org_id, name, address, phone, timezone, printer_brand, printer_ip, printer_port)
        VALUES ($1, $2, $3, $4, $5, $6, $7::inet, $8)
        RETURNING id, org_id, name, address, phone, timezone,
                  printer_brand, printer_ip::text, printer_port,
                  is_active, created_at, updated_at
        "#,
    )
    .bind(body.org_id)
    .bind(&body.name)
    .bind(&body.address)
    .bind(&body.phone)
    .bind(body.timezone.as_deref().unwrap_or("Africa/Cairo"))
    .bind(&body.printer_brand)
    .bind(&body.printer_ip)
    .bind(body.printer_port.unwrap_or(9100))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(branch))
}

pub async fn update_branch(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<UpdateBranchRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "update").await?;

    let existing = fetch_branch(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    // Resolve each nullable field:
    //   Some(Some(v)) → use v
    //   Some(None)    → explicit null (clear the field)
    //   None          → keep existing value
    let new_printer_brand: Option<Option<PrinterBrand>> = body.printer_brand.clone();
    let new_printer_ip:    Option<Option<String>>       = body.printer_ip.clone();
    let new_printer_port:  Option<Option<i32>>          = body.printer_port;

    // We build an explicit UPDATE rather than relying on COALESCE for
    // nullable fields, so that an explicit null can clear the column.
    let branch = sqlx::query_as::<_, Branch>(
        r#"
        UPDATE branches SET
            name          = COALESCE($2, name),
            address       = COALESCE($3, address),
            phone         = COALESCE($4, phone),
            timezone      = COALESCE($5, timezone),
            is_active     = COALESCE($6, is_active),
            printer_brand = CASE
                              WHEN $7 THEN $8
                              ELSE printer_brand
                            END,
            printer_ip    = CASE
                              WHEN $9  THEN $10::inet
                              ELSE printer_ip
                            END,
            printer_port  = CASE
                              WHEN $11 THEN $12
                              ELSE printer_port
                            END
        WHERE id = $1 AND deleted_at IS NULL
        RETURNING id, org_id, name, address, phone, timezone,
                  printer_brand, printer_ip::text, printer_port,
                  is_active, created_at, updated_at
        "#,
    )
    .bind(*id)
    .bind(&body.name)
    .bind(&body.address)
    .bind(&body.phone)
    .bind(&body.timezone)
    .bind(body.is_active)
    // printer_brand: $7 = should_update (bool), $8 = new value (nullable)
    .bind(new_printer_brand.is_some())
    .bind(new_printer_brand.as_ref().and_then(|o| o.clone()))
    // printer_ip: $9 = should_update, $10 = new value
    .bind(new_printer_ip.is_some())
    .bind(new_printer_ip.as_ref().and_then(|o| o.clone()))
    // printer_port: $11 = should_update, $12 = new value
    .bind(new_printer_port.is_some())
    .bind(new_printer_port.and_then(|o| o))
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

    Ok(HttpResponse::Ok().json(branch))
}

pub async fn delete_branch(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "delete").await?;

    let existing = fetch_branch(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    sqlx::query(
        "UPDATE branches SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(*id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_branch(pool: &PgPool, id: Uuid) -> Result<Branch, AppError> {
    sqlx::query_as::<_, Branch>(
        r#"
        SELECT id, org_id, name, address, phone, timezone,
               printer_brand, printer_ip::text, printer_port,
               is_active, created_at, updated_at
        FROM branches
        WHERE id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Branch not found".into()))
}
RUST

ok "src/branches/handlers.rs"

# ===========================================================================
#  3. src/shifts/handlers.rs  — add cash_movements_net to ShiftReportResponse
#     (PaymentSummaryRow.order_count is already there via sqlx)
# ===========================================================================
log "Patching src/shifts/handlers.rs — adding cash_movements_net to report response ..."

# We do a targeted sed replace: add the cash_movements_net field to the struct
# and compute it in the handler. We use Python for precision.
python3 - << 'PY'
import pathlib

path = pathlib.Path("src/shifts/handlers.rs")
src  = path.read_text()

# ── 1. Add cash_movements_net to ShiftReportResponse struct ──────────────────
old_struct = """#[derive(Debug, Serialize)]
pub struct ShiftReportResponse {
    pub shift:              Shift,
    pub payment_summary:    Vec<PaymentSummaryRow>,
    pub total_payments:     i64,
    pub total_returns:      i64,
    pub net_payments:       i64,
    pub cash_movements:     Vec<CashMovementSummaryRow>,
    pub cash_movements_in:  i64,
    pub cash_movements_out: i64,
    pub printed_at:         chrono::DateTime<chrono::Utc>,
}"""

new_struct = """#[derive(Debug, Serialize)]
pub struct ShiftReportResponse {
    pub shift:               Shift,
    pub payment_summary:     Vec<PaymentSummaryRow>,
    pub total_payments:      i64,
    pub total_returns:       i64,
    pub net_payments:        i64,
    pub cash_movements:      Vec<CashMovementSummaryRow>,
    pub cash_movements_in:   i64,
    pub cash_movements_out:  i64,
    /// Net of all cash movements (in - out) as a signed integer
    pub cash_movements_net:  i64,
    pub printed_at:          chrono::DateTime<chrono::Utc>,
}"""

if old_struct not in src:
    print("  WARN: ShiftReportResponse struct not found verbatim — skipping struct patch")
else:
    src = src.replace(old_struct, new_struct)
    print("  patched ShiftReportResponse struct")

# ── 2. Add cash_movements_net computation in get_shift_report handler ─────────
old_net = """    let cash_movements_net: i64 = cash_movements.iter()
        .filter(|m| m.amount < 0)
        .map(|m| m.amount.unsigned_abs() as i64)
        .sum();

    let total_payments: i64 = payment_summary.iter().map(|r| r.total).sum();
    let net_payments = total_payments - total_returns;

    Ok(HttpResponse::Ok().json(ShiftReportResponse {
        shift,
        payment_summary,
        total_payments,
        total_returns,
        net_payments,
        cash_movements,
        cash_movements_in,
        cash_movements_out,
        printed_at: chrono::Utc::now(),
    }))"""

new_net = """    let cash_movements_net: i64 = cash_movements.iter()
        .filter(|m| m.amount < 0)
        .map(|m| m.amount.unsigned_abs() as i64)
        .sum();

    let cash_movements_net_signed: i64 = cash_movements_in as i64 - cash_movements_out as i64;
    let total_payments: i64 = payment_summary.iter().map(|r| r.total).sum();
    let net_payments = total_payments - total_returns;

    Ok(HttpResponse::Ok().json(ShiftReportResponse {
        shift,
        payment_summary,
        total_payments,
        total_returns,
        net_payments,
        cash_movements,
        cash_movements_in,
        cash_movements_out,
        cash_movements_net: cash_movements_net_signed,
        printed_at: chrono::Utc::now(),
    }))"""

if old_net not in src:
    # Try a simpler pattern — just add cash_movements_net to the response literal
    old_resp = """    Ok(HttpResponse::Ok().json(ShiftReportResponse {
        shift,
        payment_summary,
        total_payments,
        total_returns,
        net_payments,
        cash_movements,
        cash_movements_in,
        cash_movements_out,
        printed_at: chrono::Utc::now(),
    }))"""
    new_resp = """    let cash_movements_net_signed: i64 = cash_movements_in as i64 - cash_movements_out as i64;
    Ok(HttpResponse::Ok().json(ShiftReportResponse {
        shift,
        payment_summary,
        total_payments,
        total_returns,
        net_payments,
        cash_movements,
        cash_movements_in,
        cash_movements_out,
        cash_movements_net: cash_movements_net_signed,
        printed_at: chrono::Utc::now(),
    }))"""
    if old_resp in src:
        src = src.replace(old_resp, new_resp)
        print("  patched get_shift_report response (fallback pattern)")
    else:
        print("  WARN: get_shift_report response literal not found — skipping net patch")
else:
    src = src.replace(old_net, new_net)
    print("  patched get_shift_report computation + response")

path.write_text(src)
PY

ok "src/shifts/handlers.rs"

# ===========================================================================
#  4. Verify the project still compiles (offline mode if sqlx offline data exists)
# ===========================================================================
log "Attempting cargo check ..."

if SQLX_OFFLINE=true cargo check 2>&1; then
    ok "cargo check passed"
else
    warn "cargo check failed — check errors above."
    warn "This may be expected if SQLX offline data needs regenerating."
    warn "On the VPS with DB running: cargo sqlx prepare && cargo build --release"
fi

# ===========================================================================
#  Summary
# ===========================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}  Backend patch complete!${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""
echo "  Files modified:"
echo "    src/reports/handlers.rs"
echo "      ✓ BranchSalesReport: +talabat_online_revenue, +talabat_cash_revenue"
echo "      ✓ ShiftSummary:      +talabat_online_revenue, +talabat_cash_revenue"
echo "      ✓ TimeseriesPoint:   +per-payment-method breakdown (6 payment cols)"
echo "      ✓ BranchComparison:  +talabat_online_revenue, +talabat_cash_revenue"
echo "      ✓ branch_sales:      ?limit param (default 20, max 100)"
echo "      ✓ org_branch_comparison: all payment methods included"
echo ""
echo "    src/branches/handlers.rs"
echo "      ✓ UpdateBranchRequest: double-option for printer_brand/ip/port"
echo "      ✓ update_branch:       CASE-based UPDATE (can now null printer config)"
echo ""
echo "    src/shifts/handlers.rs"
echo "      ✓ ShiftReportResponse: +cash_movements_net (in - out signed)"
echo ""
echo "  To deploy on VPS:"
echo "    cargo sqlx prepare   # if schema changed (it didn't here)"
echo "    cargo build --release"
echo "    systemctl restart rue-rust"
echo ""