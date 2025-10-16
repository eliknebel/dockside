import docker.{type DockerClient}
import gleam/http.{type Method, Delete, Get, Post}
import gleam/http/response
import gleam/int
import gleam/option
import gleam/result
import gleam/uri

fn request(
  client: DockerClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  body: option.Option(String),
) -> Result(response.Response(String), docker.DockerError) {
  docker.send_request_with_query(client, method, path, query, body, option.None)
}

fn to_body(
  res: Result(response.Response(String), docker.DockerError),
) -> Result(String, String) {
  res
  |> docker.map_error
  |> result.map(fn(r) { r.body })
}

fn to_nil(
  res: Result(response.Response(String), docker.DockerError),
) -> Result(Nil, String) {
  res
  |> docker.map_error
  |> result.map(fn(_) { Nil })
}

fn node_path(id: String, suffix: String) -> String {
  "/nodes/" <> uri.percent_encode(id) <> suffix
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

/// # List nodes
///
/// Wraps `GET /nodes`.
pub fn list(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/nodes",
    filters
    |> option.map(fn(f) { [#("filters", f)] })
    |> option.unwrap(or: []),
    option.None,
    option.None,
  )
  |> to_body
}

/// # Inspect node
///
/// Wraps `GET /nodes/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  request(client, Get, node_path(id, ""), [], option.None)
  |> to_body
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
  request(client, Post, node_path(id, "/update"), query, option.Some(body))
  |> to_nil
}

/// # Remove node
///
/// Wraps `DELETE /nodes/{id}`.
pub fn remove(
  client: DockerClient,
  id: String,
  force: Bool,
) -> Result(Nil, String) {
  request(
    client,
    Delete,
    node_path(id, ""),
    [#("force", bool_to_string(force))],
    option.None,
  )
  |> to_nil
}
