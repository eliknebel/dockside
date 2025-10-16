import docker.{type DockerClient}
import gleam/http.{type Method, Delete, Get, Post}
import gleam/http/response
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

fn volume_path(name: String, suffix: String) -> String {
  "/volumes/" <> uri.percent_encode(name) <> suffix
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

/// # List volumes
///
/// Wraps `GET /volumes`.
pub fn list(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/volumes",
    filters
    |> option.map(fn(f) { [#("filters", f)] })
    |> option.unwrap(or: []),
    option.None,
    option.None,
  )
  |> to_body
}

/// # Create volume
///
/// Wraps `POST /volumes/create`.
pub fn create(
  client: DockerClient,
  body: String,
) -> Result(String, String) {
  request(client, Post, "/volumes/create", [], option.Some(body))
  |> to_body
}

/// # Inspect volume
///
/// Wraps `GET /volumes/{name}`.
pub fn inspect(client: DockerClient, name: String) -> Result(String, String) {
  request(client, Get, volume_path(name, ""), [], option.None)
  |> to_body
}

/// # Remove volume
///
/// Wraps `DELETE /volumes/{name}`.
pub fn remove(
  client: DockerClient,
  name: String,
  force: Bool,
) -> Result(Nil, String) {
  request(
    client,
    Delete,
    volume_path(name, ""),
    [#("force", bool_to_string(force))],
    option.None,
  )
  |> to_nil
}

/// # Prune volumes
///
/// Wraps `POST /volumes/prune`.
pub fn prune(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Post,
    "/volumes/prune",
    filters
    |> option.map(fn(f) { [#("filters", f)] })
    |> option.unwrap(or: []),
    option.None,
    option.None,
  )
  |> to_body
}
