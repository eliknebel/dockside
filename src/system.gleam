import docker.{type DockerClient}
import gleam/http.{Get, Post}
import gleam/option.{None}
import request_helpers

/// # System ping
///
/// Wraps `GET /system/ping`.
pub fn ping(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/system/ping", None, None)
  |> request_helpers.expect_body
}

/// # System info
///
/// Wraps `GET /system/info`.
pub fn info(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/system/info", None, None)
  |> request_helpers.expect_body
}

/// # System version
///
/// Wraps `GET /version`.
pub fn version(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/version", None, None)
  |> request_helpers.expect_body
}

/// # System data usage
///
/// Wraps `GET /system/df`.
pub fn df(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/system/df", None, None)
  |> request_helpers.expect_body
}

/// # System events
///
/// Wraps `GET /events`.
/// Provide pre-encoded query string parameters to filter events.
pub fn events(
  client: DockerClient,
  query: List(#(String, String)),
) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query("/events", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # System prune
///
/// Wraps `POST /system/prune`.
pub fn prune(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Post, "/system/prune", None, None)
  |> request_helpers.expect_body
}
