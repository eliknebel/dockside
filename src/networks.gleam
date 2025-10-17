import docker.{type DockerClient}
import gleam/http.{Delete, Get, Post}
import gleam/option.{
  type Option, None, Some, map as option_map, unwrap as option_unwrap,
}
import gleam/uri
import request_helpers

fn network_path(id: String, suffix: String) -> String {
  "/networks/" <> uri.percent_encode(id) <> suffix
}

/// # List networks
///
/// Wraps `GET /networks`.
/// Provide `filters` as a JSON encoded string if required.
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
    request_helpers.path_with_query("/networks", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Inspect network
///
/// Wraps `GET /networks/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(network_path(id, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Create network
///
/// Wraps `POST /networks/create`.
pub fn create(client: DockerClient, body: String) -> Result(String, String) {
  docker.send_request(client, Post, "/networks/create", None, Some(body))
  |> request_helpers.expect_body
}

/// # Remove network
///
/// Wraps `DELETE /networks/{id}`.
pub fn remove(client: DockerClient, id: String) -> Result(Nil, String) {
  docker.send_request(
    client,
    Delete,
    request_helpers.path_with_query(network_path(id, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Connect container to network
///
/// Wraps `POST /networks/{id}/connect`.
pub fn connect(
  client: DockerClient,
  id: String,
  body: String,
) -> Result(Nil, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(network_path(id, "/connect"), []),
    None,
    Some(body),
  )
  |> request_helpers.expect_nil
}

/// # Disconnect container from network
///
/// Wraps `POST /networks/{id}/disconnect`.
pub fn disconnect(
  client: DockerClient,
  id: String,
  body: String,
) -> Result(Nil, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(network_path(id, "/disconnect"), []),
    None,
    Some(body),
  )
  |> request_helpers.expect_nil
}

/// # Prune networks
///
/// Wraps `POST /networks/prune`.
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
    request_helpers.path_with_query("/networks/prune", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}
