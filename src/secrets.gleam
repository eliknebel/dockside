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

fn secret_path(id: String, suffix: String) -> String {
  "/secrets/" <> uri.percent_encode(id) <> suffix
}

/// # List secrets
///
/// Wraps `GET /secrets`.
pub fn list(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/secrets",
    filters
    |> option.map(fn(f) { [#("filters", f)] })
    |> option.unwrap(or: []),
    option.None,
    option.None,
  )
  |> to_body
}

/// # Create secret
///
/// Wraps `POST /secrets/create`.
pub fn create(
  client: DockerClient,
  body: String,
) -> Result(String, String) {
  request(client, Post, "/secrets/create", [], option.Some(body))
  |> to_body
}

/// # Inspect secret
///
/// Wraps `GET /secrets/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  request(client, Get, secret_path(id, ""), [], option.None)
  |> to_body
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
  request(
    client,
    Post,
    secret_path(id, "/update"),
    [#("version", int.to_string(version))],
    option.Some(body),
  )
  |> to_nil
}

/// # Remove secret
///
/// Wraps `DELETE /secrets/{id}`.
pub fn remove(client: DockerClient, id: String) -> Result(Nil, String) {
  request(client, Delete, secret_path(id, ""), [], option.None)
  |> to_nil
}
