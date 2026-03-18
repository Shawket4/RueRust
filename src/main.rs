mod auth;
mod errors;
mod models;
mod orgs;
mod permissions;
mod users;
mod branches;
mod menu;
mod inventory;
mod recipes;
mod adjustments;
mod soft_serve;
mod shifts;
mod orders;
mod reports;
mod uploads;

use actix_cors::Cors;
use actix_files::Files;
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
    let uploads_dir = env::var("UPLOADS_DIR").unwrap_or_else(|_| "./uploads".to_string());

    // Ensure uploads root exists on startup
    std::fs::create_dir_all(&uploads_dir)
        .expect("Failed to create uploads directory");

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&db_url)
        .await
        .expect("Failed to connect to PostgreSQL");

    let pool       = web::Data::new(pool);
    let jwt_secret = web::Data::new(auth::jwt::JwtSecret(jwt_secret));
    let uploads_dir_clone = uploads_dir.clone();

    tracing::info!("Starting rue-rust on 0.0.0.0:8080");
    tracing::info!("Uploads directory: {}", uploads_dir);

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .wrap(cors)
            .app_data(pool.clone())
            .app_data(jwt_secret.clone())
            // Static file serving — public, no auth required
            .service(
                Files::new("/uploads", &uploads_dir_clone)
                    // listing disabled by default
                    .use_last_modified(true),
            )
            .configure(auth::routes::configure)
            .configure(orgs::routes::configure)
            .configure(users::routes::configure)
            .configure(permissions::routes::configure)
            .configure(branches::routes::configure)
            .configure(menu::routes::configure)
            .configure(inventory::routes::configure)
            .configure(recipes::routes::configure)
            .configure(adjustments::routes::configure)
            .configure(soft_serve::routes::configure)
            .configure(shifts::routes::configure)
            .configure(orders::routes::configure)
            .configure(reports::routes::configure)
            .configure(uploads::routes::configure)
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
