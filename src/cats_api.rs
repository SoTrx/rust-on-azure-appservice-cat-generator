use crate::types;
use log::{debug, error};
use serde::Deserialize;
use std::env;
/// Return a (borrowable) random cat url
pub async fn get_random_cat_url() -> types::Result<String> {
    if env::var("API_KEY").unwrap().is_empty() {
        error!("Cat API_KEY isn't provided, cannot proceed");
        return Err("Missing API_KEY".into());
    }
    debug!("The current API_KEY is {}", env::var("API_KEY")?);
    let cats: Vec<Cat> = reqwest::Client::new()
        .get("https://api.thecatapi.com/v1/images/search")
        .header("x-api-key", env::var("API_KEY")?)
        .send()
        .await?
        .json()
        .await?;
    Ok(cats.first().take().unwrap().url.clone())
}

#[derive(Deserialize, Debug)]
struct Cat {
    /// Cat's picture url
    url: String,
}
