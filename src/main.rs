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
use std::{env, fs};
use tracing_subscriber::EnvFilter;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let db_url      = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let uploads_dir = env::var("UPLOADS_DIR").unwrap_or_else(|_| "./uploads".to_string());

    fs::create_dir_all(&uploads_dir).expect("Failed to create uploads directory");

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&db_url)
        .await
        .expect("Failed to connect to PostgreSQL");

    let pool          = web::Data::new(pool);
    let uploads_clone = uploads_dir.clone();
    let bind_addr     = env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".to_string());

    let tls_config = build_tls_config();

    tracing::info!("Starting rue-rust");
    tracing::info!("Uploads directory: {}", uploads_dir);

    let server = HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .wrap(cors)
            .app_data(pool.clone())
            .service(Files::new("/uploads", &uploads_clone).use_last_modified(true))
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
    });

    if let Some(tls) = tls_config {
        tracing::info!("HTTPS on {}", bind_addr);
        server.bind_rustls_0_23(&bind_addr, tls)?.run().await
    } else {
        tracing::info!("HTTP on {} (no TLS certs found)", bind_addr);
        server.bind(&bind_addr)?.run().await
    }
}

fn build_tls_config() -> Option<rustls::ServerConfig> {
    let cert_file = env::var("SSL_CERT_FILE").ok()?;
    let key_file  = env::var("SSL_KEY_FILE").ok()?;
    if cert_file.is_empty() || key_file.is_empty() { return None; }

    let cert_pem = fs::read(&cert_file).ok().or_else(|| {
        tracing::warn!("SSL_CERT_FILE not found: {}", cert_file); None
    })?;
    let key_pem = fs::read(&key_file).ok().or_else(|| {
        tracing::warn!("SSL_KEY_FILE not found: {}", key_file); None
    })?;

    let certs: Vec<rustls::pki_types::CertificateDer> =
        rustls_pemfile::certs(&mut cert_pem.as_slice())
            .filter_map(|c| c.ok()).collect();

    let mut keys: Vec<rustls::pki_types::PrivateKeyDer> =
        rustls_pemfile::pkcs8_private_keys(&mut key_pem.as_slice())
            .filter_map(|k| k.ok().map(rustls::pki_types::PrivateKeyDer::from))
            .collect();

    if keys.is_empty() {
        keys = rustls_pemfile::rsa_private_keys(&mut key_pem.as_slice())
            .filter_map(|k| k.ok().map(rustls::pki_types::PrivateKeyDer::from))
            .collect();
    }

    if certs.is_empty() || keys.is_empty() {
        tracing::warn!("Could not parse TLS certs/keys — falling back to HTTP");
        return None;
    }

    rustls::ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(certs, keys.remove(0))
        .map_err(|e| { tracing::warn!("TLS config error: {}", e); e })
        .ok()
}