use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server};
use std::{convert::Infallible, env, net::SocketAddr};
mod cats_api;
mod types;
extern crate dotenv;
use dotenv::dotenv;
use log::{error, info};

const SERVER_PORT: u16 = 8081;
const SERVER_HOST: [u8; 4] = [127, 0, 0, 1];

/// Search and return a random cat image
async fn serve_random_cat(_req: Request<Body>) -> types::Result<Response<Body>> {
    let cat_url = cats_api::get_random_cat_url().await?;
    // Download the cat image from its URL and send the blob back in the response
    let bytes = reqwest::get(cat_url).await?.bytes().await?;
    Ok(Response::new(bytes.into()))
}

#[tokio::main]
async fn main() {
    env_logger::init();
    dotenv().ok();
    info!("Now starting cat server !");

    if env::var("API_KEY").unwrap().is_empty() {
        error!("No cats API_KEY found ! Aborting !");
        panic!();
    }
    // Boot up the server, SERVER_PORT should always be available, this is running in a
    // container
    let socket = SocketAddr::from((SERVER_HOST, SERVER_PORT));
    // Server handler
    let handler =
        make_service_fn(|_conn| async { Ok::<_, Infallible>(service_fn(serve_random_cat)) });
    let server = Server::bind(&socket).serve(handler);
    info!("Server listening to {:?}:{} !", SERVER_HOST, SERVER_PORT);

    // Run the server until
    if let Err(e) = server.await {
        error!("Server error: {}", e);
        panic!();
    }
}
