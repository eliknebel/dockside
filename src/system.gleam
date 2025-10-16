import docker.{type DockerClient}
import gleam/http.{Get, Post}
import gleam/http/response
import gleam/option
import gleam/result

fn to_body(
  res: Result(response.Response(String), docker.DockerError),
) -> Result(String, String) {
  res
  |> docker.map_error
  |> result.map(fn(r) { r.body })
}

/// # System ping
///
/// Wraps `GET /system/ping`.
pub fn ping(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/system/ping", option.None, option.None)
  |> to_body
}

/// # System info
///
/// Wraps `GET /system/info`.
pub fn info(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/system/info", option.None, option.None)
  |> to_body
}

/// # System version
///
/// Wraps `GET /version`.
pub fn version(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/version", option.None, option.None)
  |> to_body
}

/// # System data usage
///
/// Wraps `GET /system/df`.
pub fn df(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/system/df", option.None, option.None)
  |> to_body
}

/// # System events
///
/// Wraps `GET /events`.
/// Provide pre-encoded query string parameters to filter events.
pub fn events(
  client: DockerClient,
  query: List(#(String, String)),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/events",
    query,
    option.None,
    option.None,
  )
  |> to_body
}

/// # System prune
///
/// Wraps `POST /system/prune`.
pub fn prune(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Post, "/system/prune", option.None, option.None)
  |> to_body
}
