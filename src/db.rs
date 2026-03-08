use sqlx::{postgres::PgPoolOptions, PgPool};

pub async fn create_pool(url: &str) -> PgPool {
    PgPoolOptions::new()
        .max_connections(10)
        .connect(url)
        .await
        .expect("Failed to connect to PostgreSQL")
}