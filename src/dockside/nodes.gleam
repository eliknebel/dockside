import dockside/docker.{type DockerClient}
import dockside/request_helpers
import gleam/http.{Delete, Get, Post}
import gleam/int
import gleam/option.{
  type Option, None, Some, map as option_map, unwrap as option_unwrap,
}
import gleam/uri

fn node_path(id: String, suffix: String) -> String {
  "/nodes/" <> uri.percent_encode(id) <> suffix
}

/// # List nodes
///
/// Wraps `GET /nodes`.
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
    request_helpers.path_with_query("/nodes", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Inspect node
///
/// Wraps `GET /nodes/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(node_path(id, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Update node
///
/// Wraps `POST /nodes/{id}/update`.
pub fn update(
  client: DockerClient,
  id: String,
  version: Int,
  body: String,
) -> Result(Nil, String) {
  let query = [#("version", int.to_string(version))]
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(node_path(id, "/update"), query),
    None,
    Some(body),
  )
  |> request_helpers.expect_nil
}

/// # Remove node
///
/// Wraps `DELETE /nodes/{id}`.
pub fn remove(
  client: DockerClient,
  id: String,
  force: Bool,
) -> Result(Nil, String) {
  docker.send_request(
    client,
    Delete,
    request_helpers.path_with_query(node_path(id, ""), [
      #("force", request_helpers.bool_to_string(force)),
    ]),
    None,
    None,
  )
  |> request_helpers.expect_nil
}
