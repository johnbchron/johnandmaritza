use axum::{
  Router, body::Body, http::Response, response::IntoResponse, routing::get,
};
use columbo::Html;
use maud::{Markup, html};
use miette::{Context, IntoDiagnostic};

fn page_wrapper(inner: Markup) -> Markup {
  html! {
    (maud::DOCTYPE)
    html {
      head {
        title { "John and Maritza" }
      }
      body {
        ( inner )
      }
    }
  }
}

fn columbo_stream_to_axum_resp(
  resp: columbo::SuspendedResponse,
  doc: impl Into<Html>,
) -> Response<Body> {
  let body = Body::from_stream(resp.into_stream(doc));
  Response::builder()
    .header("Content-Type", "text/html; charset=utf-8")
    .header("Transfer-Encoding", "chunked")
    .header("X-Content-Type-Options", "nosniff")
    .body(body)
    .unwrap()
}

async fn root() -> impl IntoResponse {
  let (_ctx, resp) = columbo::new();

  let page = {
    html! {
      h1 { "Welcome to John & Maritza's wedding site!" }
    }
  };
  let doc = page_wrapper(page);
  columbo_stream_to_axum_resp(resp, doc)
}

#[tokio::main]
async fn main() -> miette::Result<()> {
  let app = Router::new().route("/", get(root));

  let listener = tokio::net::TcpListener::bind("[::]:3000")
    .await
    .into_diagnostic()
    .context("failed to bind to port")?;
  axum::serve(listener, app).await.unwrap();

  Ok(())
}
