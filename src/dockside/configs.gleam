import dockside/docker.{type DockerClient}
import dockside/request_helpers
import gleam/http.{Delete, Get, Post}
import gleam/int
import gleam/option.{
  type Option, None, Some, map as option_map, unwrap as option_unwrap,
}
import gleam/uri

fn config_path(id: String, suffix: String) -> String {
  "/configs/" <> uri.percent_encode(id) <> suffix
}

/// # List configs
///
/// Wraps `GET /configs`.
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
    request_helpers.path_with_query("/configs", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Create config
///
/// Wraps `POST /configs/create`.
pub fn create(client: DockerClient, body: String) -> Result(String, String) {
  docker.send_request(client, Post, "/configs/create", None, Some(body))
  |> request_helpers.expect_body
}

/// # Inspect config
///
/// Wraps `GET /configs/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(config_path(id, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Update config
///
/// Wraps `POST /configs/{id}/update`.
pub fn update(
  client: DockerClient,
  id: String,
  version: Int,
  body: String,
) -> Result(Nil, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(config_path(id, "/update"), [
      #("version", int.to_string(version)),
    ]),
    None,
    Some(body),
  )
  |> request_helpers.expect_nil
}

/// # Remove config
///
/// Wraps `DELETE /configs/{id}`.
pub fn remove(client: DockerClient, id: String) -> Result(Nil, String) {
  docker.send_request(
    client,
    Delete,
    request_helpers.path_with_query(config_path(id, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_nil
}
