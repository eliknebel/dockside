import docker.{type DockerClient}
import gleam/http.{Delete, Get, Post}
import gleam/int
import gleam/option.{
  type Option, None, Some, map as option_map, unwrap as option_unwrap,
}
import gleam/uri
import request_helpers

fn secret_path(id: String, suffix: String) -> String {
  "/secrets/" <> uri.percent_encode(id) <> suffix
}

/// # List secrets
///
/// Wraps `GET /secrets`.
pub fn list(
  client: DockerClient,
  filters: Option(String),
) -> Result(String, String) {
  let query =
    filters
    |> option_map(fn(f) { [#("filters", f)] })
    |> option_unwrap(or: [])

  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query("/secrets", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Create secret
///
/// Wraps `POST /secrets/create`.
pub fn create(client: DockerClient, body: String) -> Result(String, String) {
  docker.send_request(client, Post, "/secrets/create", None, Some(body))
  |> request_helpers.expect_body
}

/// # Inspect secret
///
/// Wraps `GET /secrets/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(secret_path(id, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Update secret
///
/// Wraps `POST /secrets/{id}/update`.
pub fn update(
  client: DockerClient,
  id: String,
  version: Int,
  body: String,
) -> Result(Nil, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(secret_path(id, "/update"), [
      #("version", int.to_string(version)),
    ]),
    None,
    Some(body),
  )
  |> request_helpers.expect_nil
}

/// # Remove secret
///
/// Wraps `DELETE /secrets/{id}`.
pub fn remove(client: DockerClient, id: String) -> Result(Nil, String) {
  docker.send_request(
    client,
    Delete,
    request_helpers.path_with_query(secret_path(id, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_nil
}
