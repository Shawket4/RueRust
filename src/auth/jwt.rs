use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::models::UserRole;

pub struct JwtSecret(pub String);

#[derive(Debug, Clone, Serialize, Deserialize)]  // Clone added
pub struct Claims {
    pub sub:       String,
    pub org_id:    String,
    pub role:      UserRole,
    pub branch_id: Option<String>,
    pub exp:       usize,
    pub iat:       usize,
}

impl Claims {
    pub fn user_id(&self) -> Uuid { Uuid::parse_str(&self.sub).unwrap() }
    pub fn org_id(&self)   -> Uuid { Uuid::parse_str(&self.org_id).unwrap() }
}

pub fn create_token(
    secret:    &JwtSecret,
    user_id:   Uuid,
    org_id:    Uuid,
    role:      UserRole,
    branch_id: Option<Uuid>,
    hours:     i64,
) -> Result<String, jsonwebtoken::errors::Error> {
    let now = Utc::now();
    let claims = Claims {
        sub:       user_id.to_string(),
        org_id:    org_id.to_string(),
        role,
        branch_id: branch_id.map(|b| b.to_string()),
        iat:       now.timestamp() as usize,
        exp:       (now + Duration::hours(hours)).timestamp() as usize,
    };
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.0.as_bytes()),
    )
}

pub fn verify_token(secret: &JwtSecret, token: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.0.as_bytes()),
        &Validation::default(),
    )?;
    Ok(data.claims)
}