import docker.{type DockerClient}
import gleam/http.{type Method, Delete, Get, Post}
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/uri

pub type LogsOptions {
  LogsOptions(
    follow: Bool,
    stdout: Bool,
    stderr: Bool,
    since: option.Option(Int),
    timestamps: Bool,
    tail: option.Option(String),
    details: Bool,
  )
}

pub fn default_logs_options() -> LogsOptions {
  LogsOptions(
    follow: False,
    stdout: True,
    stderr: True,
    since: option.None,
    timestamps: False,
    tail: option.None,
    details: False,
  )
}

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

fn service_path(id: String, suffix: String) -> String {
  "/services/" <> uri.percent_encode(id) <> suffix
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

fn append_bool(
  query: List(#(String, String)),
  key: String,
  value: Bool,
) -> List(#(String, String)) {
  list.append(query, [#(key, bool_to_string(value))])
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
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

/// # List services
///
/// Wraps `GET /services`.
pub fn list(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/services",
    filters
    |> option.map(fn(f) { [#("filters", f)] })
    |> option.unwrap(or: []),
    option.None,
    option.None,
  )
  |> to_body
}

/// # Inspect service
///
/// Wraps `GET /services/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  request(client, Get, service_path(id, ""), [], option.None, option.None)
  |> to_body
}

/// # Create service
///
/// Wraps `POST /services/create`.
pub fn create(
  client: DockerClient,
  body: String,
  registry_auth: option.Option(String),
) -> Result(String, String) {
  let headers =
    case registry_auth {
      option.Some(auth) -> option.Some([#("X-Registry-Auth", auth)])
      option.None -> option.None
    }

  request(client, Post, "/services/create", [], option.Some(body), headers)
  |> to_body
}

/// # Update service
///
/// Wraps `POST /services/{id}/update`.
pub fn update(
  client: DockerClient,
  id: String,
  version: Int,
  registry_auth_header: option.Option(String),
  registry_auth_from: option.Option(String),
  rollback: option.Option(String),
  body: String,
) -> Result(Nil, String) {
  let query =
    []
    |> list.append([#("version", int.to_string(version))])
    |> append_optional("registryAuthFrom", registry_auth_from)
    |> append_optional("rollback", rollback)

  let headers =
    case registry_auth_header {
      option.Some(auth) -> option.Some([#("X-Registry-Auth", auth)])
      option.None -> option.None
    }

  request(
    client,
    Post,
    service_path(id, "/update"),
    query,
    option.Some(body),
    headers,
  )
  |> to_nil
}

/// # Remove service
///
/// Wraps `DELETE /services/{id}`.
pub fn remove(client: DockerClient, id: String) -> Result(Nil, String) {
  request(client, Delete, service_path(id, ""), [], option.None, option.None)
  |> to_nil
}

/// # Service logs
///
/// Wraps `GET /services/{id}/logs`.
pub fn logs(
  client: DockerClient,
  id: String,
  options: LogsOptions,
) -> Result(String, String) {
  let LogsOptions(
    follow: follow,
    stdout: stdout,
    stderr: stderr,
    since: since,
    timestamps: timestamps,
    tail: tail,
    details: details,
  ) = options

  let query =
    []
    |> append_bool("follow", follow)
    |> append_bool("stdout", stdout)
    |> append_bool("stderr", stderr)
    |> append_optional("since", int_option_to_string(since))
    |> append_bool("timestamps", timestamps)
    |> append_optional("tail", tail)
    |> append_bool("details", details)

  request(
    client,
    Get,
    service_path(id, "/logs"),
    query,
    option.None,
    option.None,
  )
  |> to_body
}
