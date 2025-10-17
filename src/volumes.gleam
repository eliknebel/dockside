import docker.{type DockerClient}
import gleam/http.{Delete, Get, Post}
import gleam/option.{
  type Option, None, Some, map as option_map, unwrap as option_unwrap,
}
import gleam/uri
import request_helpers

fn volume_path(name: String, suffix: String) -> String {
  "/volumes/" <> uri.percent_encode(name) <> suffix
}

/// # List volumes
///
/// Wraps `GET /volumes`.
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
    request_helpers.path_with_query("/volumes", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Create volume
///
/// Wraps `POST /volumes/create`.
pub fn create(client: DockerClient, body: String) -> Result(String, String) {
  docker.send_request(client, Post, "/volumes/create", None, Some(body))
  |> request_helpers.expect_body
}

/// # Inspect volume
///
/// Wraps `GET /volumes/{name}`.
pub fn inspect(client: DockerClient, name: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(volume_path(name, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Remove volume
///
/// Wraps `DELETE /volumes/{name}`.
pub fn remove(
  client: DockerClient,
  name: String,
  force: Bool,
) -> Result(Nil, String) {
  docker.send_request(
    client,
    Delete,
    request_helpers.path_with_query(volume_path(name, ""), [
      #("force", request_helpers.bool_to_string(force)),
    ]),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Prune volumes
///
/// Wraps `POST /volumes/prune`.
pub fn prune(
  client: DockerClient,
  filters: Option(String),
) -> Result(String, String) {
  let query =
    filters
    |> option_map(fn(f) { [#("filters", f)] })
    |> option_unwrap(or: [])

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query("/volumes/prune", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}
