import dockside/docker.{type DockerClient}
import dockside/request_helpers
import gleam/http.{Get, Post}
import gleam/option.{type Option, None, Some}
import gleam/uri

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
  docker.send_request(
    client,
    Post,
    "/containers/" <> uri.percent_encode(container_id) <> "/exec",
    None,
    Some(body),
  )
  |> request_helpers.expect_body
}

/// # Start exec
///
/// Wraps `POST /exec/{id}/start`.
pub fn start(
  client: DockerClient,
  id: String,
  body: String,
) -> Result(String, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(exec_path(id, "/start"), []),
    None,
    Some(body),
  )
  |> request_helpers.expect_body
}

/// # Inspect exec
///
/// Wraps `GET /exec/{id}/json`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(exec_path(id, "/json"), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Resize exec TTY
///
/// Wraps `POST /exec/{id}/resize`.
pub fn resize(
  client: DockerClient,
  id: String,
  height: Option(Int),
  width: Option(Int),
) -> Result(Nil, String) {
  let query =
    []
    |> request_helpers.append_optional(
      "h",
      request_helpers.int_option_to_string(height),
    )
    |> request_helpers.append_optional(
      "w",
      request_helpers.int_option_to_string(width),
    )

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(exec_path(id, "/resize"), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}
