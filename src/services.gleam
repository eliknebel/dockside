import docker.{type DockerClient}
import gleam/http.{Delete, Get, Post}
import gleam/int
import gleam/list
import gleam/option.{
  type Option, None, Some, map as option_map, unwrap as option_unwrap,
}
import gleam/uri
import request_helpers

pub type LogsOptions {
  LogsOptions(
    follow: Bool,
    stdout: Bool,
    stderr: Bool,
    since: Option(Int),
    timestamps: Bool,
    tail: Option(String),
    details: Bool,
  )
}

pub fn default_logs_options() -> LogsOptions {
  LogsOptions(
    follow: False,
    stdout: True,
    stderr: True,
    since: None,
    timestamps: False,
    tail: None,
    details: False,
  )
}

fn service_path(id: String, suffix: String) -> String {
  "/services/" <> uri.percent_encode(id) <> suffix
}

/// # List services
///
/// Wraps `GET /services`.
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
    request_helpers.path_with_query("/services", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Inspect service
///
/// Wraps `GET /services/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(service_path(id, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Create service
///
/// Wraps `POST /services/create`.
pub fn create(
  client: DockerClient,
  body: String,
  registry_auth: Option(String),
) -> Result(String, String) {
  let headers = case registry_auth {
    Some(auth) -> Some([#("X-Registry-Auth", auth)])
    None -> None
  }

  docker.send_request(client, Post, "/services/create", headers, Some(body))
  |> request_helpers.expect_body
}

/// # Update service
///
/// Wraps `POST /services/{id}/update`.
pub fn update(
  client: DockerClient,
  id: String,
  version: Int,
  registry_auth_header: Option(String),
  registry_auth_from: Option(String),
  rollback: Option(String),
  body: String,
) -> Result(Nil, String) {
  let query =
    []
    |> list.append([#("version", int.to_string(version))])
    |> request_helpers.append_optional("registryAuthFrom", registry_auth_from)
    |> request_helpers.append_optional("rollback", rollback)

  let headers = case registry_auth_header {
    Some(auth) -> Some([#("X-Registry-Auth", auth)])
    None -> None
  }

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(service_path(id, "/update"), query),
    headers,
    Some(body),
  )
  |> request_helpers.expect_nil
}

/// # Remove service
///
/// Wraps `DELETE /services/{id}`.
pub fn remove(client: DockerClient, id: String) -> Result(Nil, String) {
  docker.send_request(
    client,
    Delete,
    request_helpers.path_with_query(service_path(id, ""), []),
    None,
    None,
  )
  |> request_helpers.expect_nil
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
    |> request_helpers.append_bool("follow", follow)
    |> request_helpers.append_bool("stdout", stdout)
    |> request_helpers.append_bool("stderr", stderr)
    |> request_helpers.append_optional(
      "since",
      request_helpers.int_option_to_string(since),
    )
    |> request_helpers.append_bool("timestamps", timestamps)
    |> request_helpers.append_optional("tail", tail)
    |> request_helpers.append_bool("details", details)

  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(service_path(id, "/logs"), query),
    None,
    None,
  )
  |> request_helpers.expect_body
}
