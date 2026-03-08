mod auth;
mod db;
mod errors;
mod models;
mod orgs;
mod users;

use actix_web::{web, App, HttpServer};
use dotenvy::dotenv;
use sqlx::postgres::PgPoolOptions;
use std::env;
use tracing_subscriber::EnvFilter;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let db_url     = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let jwt_secret = env::var("JWT_SECRET").expect("JWT_SECRET must be set");

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&db_url)
        .await
        .expect("Failed to connect to PostgreSQL");

    let pool       = web::Data::new(pool);
    let jwt_secret = web::Data::new(auth::jwt::JwtSecret(jwt_secret));

    tracing::info!("Starting rue-rust on 0.0.0.0:8080");

    HttpServer::new(move || {
        App::new()
            .app_data(pool.clone())
            .app_data(jwt_secret.clone())
            .configure(auth::routes::configure)
            .configure(orgs::routes::configure)
            .configure(users::routes::configure)
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}