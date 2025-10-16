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

/// # Inspect distribution image
///
/// Wraps `GET /distribution/{name}/json`.
pub fn inspect(client: DockerClient, name: String) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Get,
    "/distribution/" <> uri.percent_encode(name) <> "/json",
    [],
    option.None,
    option.None,
  )
  |> to_body
}
