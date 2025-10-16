import docker.{type DockerClient}
import gleam/http.{type Method, Get, Post}
import gleam/http/response
import gleam/int
import gleam/option
import gleam/result
import gleam/uri
import gleam/list

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

fn exec_path(id: String, suffix: String) -> String {
  "/exec/" <> uri.percent_encode(id) <> suffix
}

/// # Create exec configuration
///
/// Wraps `POST /containers/{id}/exec`.
pub fn create(
  client: DockerClient,
  container_id: String,
  body: String,
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Post,
    "/containers/" <> uri.percent_encode(container_id) <> "/exec",
    [],
    option.Some(body),
    option.None,
  )
  |> to_body
}

/// # Start exec
///
/// Wraps `POST /exec/{id}/start`.
pub fn start(
  client: DockerClient,
  id: String,
  body: String,
) -> Result(String, String) {
  request(client, Post, exec_path(id, "/start"), [], option.Some(body))
  |> to_body
}

/// # Inspect exec
///
/// Wraps `GET /exec/{id}/json`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  request(client, Get, exec_path(id, "/json"), [], option.None)
  |> to_body
}

/// # Resize exec TTY
///
/// Wraps `POST /exec/{id}/resize`.
pub fn resize(
  client: DockerClient,
  id: String,
  height: option.Option(Int),
  width: option.Option(Int),
) -> Result(Nil, String) {
  let query =
    []
    |> append_optional("h", int_option_to_string(height))
    |> append_optional("w", int_option_to_string(width))

  request(client, Post, exec_path(id, "/resize"), query, option.None)
  |> to_nil
}

fn append_optional(
  query: List(#(String, String)),
  key: String,
  value: option.Option(String),
) -> List(#(String, String)) {
  case value {
    option.Some(v) -> list.append(query, [#(key, v)])
    option.None -> query
  }
}

fn int_option_to_string(
  value: option.Option(Int),
) -> option.Option(String) {
  case value {
    option.Some(v) -> option.Some(int.to_string(v))
    option.None -> option.None
  }
}
