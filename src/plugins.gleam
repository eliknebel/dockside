import docker.{type DockerClient}
import gleam/http.{type Method, Delete, Get, Post}
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/uri

fn request(
  client: DockerClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  body: option.Option(String),
  headers: option.Option(List(#(String, String))),
) -> Result(response.Response(String), docker.DockerError) {
  docker.send_request_with_query(client, method, path, query, body, headers)
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

fn plugin_path(name: String, suffix: String) -> String {
  "/plugins/" <> uri.percent_encode(name) <> suffix
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

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

/// # List plugins
///
/// Wraps `GET /plugins`.
pub fn list(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/plugins",
    filters
    |> option.map(fn(f) { [#("filters", f)] })
    |> option.unwrap(or: []),
    option.None,
    option.None,
  )
  |> to_body
}

/// # Inspect plugin
///
/// Wraps `GET /plugins/{name}/json`.
pub fn inspect(client: DockerClient, name: String) -> Result(String, String) {
  request(client, Get, plugin_path(name, "/json"), [], option.None, option.None)
  |> to_body
}

/// # Enable plugin
///
/// Wraps `POST /plugins/{name}/enable`.
pub fn enable(
  client: DockerClient,
  name: String,
  timeout: option.Option(Int),
) -> Result(Nil, String) {
  let query = [] |> append_optional("timeout", int_option_to_string(timeout))
  request(client, Post, plugin_path(name, "/enable"), query, option.None, option.None)
  |> to_nil
}

/// # Disable plugin
///
/// Wraps `POST /plugins/{name}/disable`.
pub fn disable(
  client: DockerClient,
  name: String,
  force: Bool,
) -> Result(Nil, String) {
  request(
    client,
    Post,
    plugin_path(name, "/disable"),
    [#("force", bool_to_string(force))],
    option.None,
    option.None,
  )
  |> to_nil
}

/// # Remove plugin
///
/// Wraps `DELETE /plugins/{name}`.
pub fn remove(
  client: DockerClient,
  name: String,
  force: Bool,
) -> Result(Nil, String) {
  request(
    client,
    Delete,
    plugin_path(name, ""),
    [#("force", bool_to_string(force))],
    option.None,
    option.None,
  )
  |> to_nil
}

/// # Install plugin
///
/// Wraps `POST /plugins/pull`.
pub fn install(
  client: DockerClient,
  remote: String,
  name: option.Option(String),
  registry_auth: option.Option(String),
) -> Result(String, String) {
  let query =
    []
    |> list.append([#("remote", remote)])
    |> append_optional("name", name)

  let headers =
    case registry_auth {
      option.Some(auth) -> option.Some([#("X-Registry-Auth", auth)])
      option.None -> option.None
    }

  request(client, Post, "/plugins/pull", query, option.None, headers)
  |> to_body
}

/// # Upgrade plugin
///
/// Wraps `POST /plugins/{name}/upgrade`.
pub fn upgrade(
  client: DockerClient,
  name: String,
  remote: option.Option(String),
  registry_auth: option.Option(String),
  body: String,
) -> Result(String, String) {
  let query = [] |> append_optional("remote", remote)

  let headers =
    case registry_auth {
      option.Some(auth) -> option.Some([#("X-Registry-Auth", auth)])
      option.None -> option.None
    }

  request(
    client,
    Post,
    plugin_path(name, "/upgrade"),
    query,
    option.Some(body),
    headers,
  )
  |> to_body
}

/// # Push plugin
///
/// Wraps `POST /plugins/{name}/push`.
pub fn push(
  client: DockerClient,
  name: String,
) -> Result(String, String) {
  request(client, Post, plugin_path(name, "/push"), [], option.None, option.None)
  |> to_body
}
