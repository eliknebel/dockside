import docker.{type DockerClient}
import gleam/http.{Get}
import gleam/http/response
import gleam/option
import gleam/result
import gleam/uri

fn to_body(
  res: Result(response.Response(String), docker.DockerError),
) -> Result(String, String) {
  res
  |> docker.map_error
  |> result.map(fn(r) { r.body })
}

/// # List tasks
///
/// Wraps `GET /tasks`.
pub fn list(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/tasks",
    filters
    |> option.map(fn(f) { [#("filters", f)] })
    |> option.unwrap(or: []),
    option.None,
    option.None,
  )
  |> to_body
}

/// # Inspect task
///
/// Wraps `GET /tasks/{id}`.
pub fn inspect(client: DockerClient, id: String) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/tasks/" <> uri.percent_encode(id),
    [],
    option.None,
    option.None,
  )
  |> to_body
}
