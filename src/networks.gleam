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

fn network_path(id: String, suffix: String) -> String {
  "/networks/" <> uri.percent_encode(id) <> suffix
}

/// # List networks
///
/// Wraps `GET /networks`.
/// Provide `filters` as a JSON encoded string if required.
pub fn list(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/networks",
    filters
    |> option.map(fn(f) { [#("filters", f)] })
    |> option.unwrap(or: []),
    option.None,
    option.None,
  )
  |> to_body
}

/// # Inspect network
///
/// Wraps `GET /networks/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  request(client, Get, network_path(id, ""), [], option.None)
  |> to_body
}

/// # Create network
///
/// Wraps `POST /networks/create`.
pub fn create(
  client: DockerClient,
  body: String,
) -> Result(String, String) {
  request(client, Post, "/networks/create", [], option.Some(body))
  |> to_body
}

/// # Remove network
///
/// Wraps `DELETE /networks/{id}`.
pub fn remove(client: DockerClient, id: String) -> Result(Nil, String) {
  request(client, Delete, network_path(id, ""), [], option.None)
  |> to_nil
}

/// # Connect container to network
///
/// Wraps `POST /networks/{id}/connect`.
pub fn connect(
  client: DockerClient,
  id: String,
  body: String,
) -> Result(Nil, String) {
  request(
    client,
    Post,
    network_path(id, "/connect"),
    [],
    option.Some(body),
  )
  |> to_nil
}

/// # Disconnect container from network
///
/// Wraps `POST /networks/{id}/disconnect`.
pub fn disconnect(
  client: DockerClient,
  id: String,
  body: String,
) -> Result(Nil, String) {
  request(
    client,
    Post,
    network_path(id, "/disconnect"),
    [],
    option.Some(body),
  )
  |> to_nil
}

/// # Prune networks
///
/// Wraps `POST /networks/prune`.
pub fn prune(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Post,
    "/networks/prune",
    filters
    |> option.map(fn(f) { [#("filters", f)] })
    |> option.unwrap(or: []),
    option.None,
    option.None,
  )
  |> to_body
}
