import dockside/docker.{type DockerClient}
import dockside/request_helpers
import gleam/http.{Delete, Get, Post}
import gleam/list
import gleam/option.{
  type Option, None, Some, map as option_map, unwrap as option_unwrap,
}
import gleam/uri

fn plugin_path(name: String, suffix: String) -> String {
  "/plugins/" <> uri.percent_encode(name) <> suffix
}

/// # List plugins
///
/// Wraps `GET /plugins`.
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
    request_helpers.path_with_query("/plugins", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Inspect plugin
///
/// Wraps `GET /plugins/{name}/json`.
pub fn inspect(client: DockerClient, name: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(plugin_path(name, "/json"), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Enable plugin
///
/// Wraps `POST /plugins/{name}/enable`.
pub fn enable(
  client: DockerClient,
  name: String,
  timeout: Option(Int),
) -> Result(Nil, String) {
  let query =
    []
    |> request_helpers.append_optional(
      "timeout",
      request_helpers.int_option_to_string(timeout),
    )

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(plugin_path(name, "/enable"), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Disable plugin
///
/// Wraps `POST /plugins/{name}/disable`.
pub fn disable(
  client: DockerClient,
  name: String,
  force: Bool,
) -> Result(Nil, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(plugin_path(name, "/disable"), [
      #("force", request_helpers.bool_to_string(force)),
    ]),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Remove plugin
///
/// Wraps `DELETE /plugins/{name}`.
pub fn remove(
  client: DockerClient,
  name: String,
  force: Bool,
) -> Result(Nil, String) {
  docker.send_request(
    client,
    Delete,
    request_helpers.path_with_query(plugin_path(name, ""), [
      #("force", request_helpers.bool_to_string(force)),
    ]),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Install plugin
///
/// Wraps `POST /plugins/pull`.
pub fn install(
  client: DockerClient,
  remote: String,
  name: Option(String),
  registry_auth: Option(String),
) -> Result(String, String) {
  let query =
    []
    |> list.append([#("remote", remote)])
    |> request_helpers.append_optional("name", name)

  let headers = case registry_auth {
    Some(auth) -> Some([#("X-Registry-Auth", auth)])
    None -> None
  }

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query("/plugins/pull", query),
    headers,
    None,
  )
  |> request_helpers.expect_body
}

/// # Upgrade plugin
///
/// Wraps `POST /plugins/{name}/upgrade`.
pub fn upgrade(
  client: DockerClient,
  name: String,
  remote: Option(String),
  registry_auth: Option(String),
  body: String,
) -> Result(String, String) {
  let query = [] |> request_helpers.append_optional("remote", remote)

  let headers = case registry_auth {
    Some(auth) -> Some([#("X-Registry-Auth", auth)])
    None -> None
  }

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(plugin_path(name, "/upgrade"), query),
    headers,
    Some(body),
  )
  |> request_helpers.expect_body
}

/// # Push plugin
///
/// Wraps `POST /plugins/{name}/push`.
pub fn push(client: DockerClient, name: String) -> Result(String, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(plugin_path(name, "/push"), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}
