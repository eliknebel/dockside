import docker.{type DockerClient}
import gleam/http.{Get}
import gleam/option.{
  type Option, None, map as option_map, unwrap as option_unwrap,
}
import gleam/uri
import request_helpers

/// # List tasks
///
/// Wraps `GET /tasks`.
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
    request_helpers.path_with_query("/tasks", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Inspect task
///
/// Wraps `GET /tasks/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    "/tasks/" <> uri.percent_encode(id),
    None,
    None,
  )
  |> request_helpers.expect_body
}
