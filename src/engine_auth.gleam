import docker.{type DockerClient}
import gleam/http.{Post}
import gleam/http/response
import gleam/option
import gleam/result

fn to_body(
  res: Result(response.Response(String), docker.DockerError),
) -> Result(String, String) {
  res
  |> docker.map_error
  |> result.map(fn(r) { r.body })
}

/// # Check auth configuration
///
/// Wraps `POST /auth`.
pub fn check(client: DockerClient, body: String) -> Result(String, String) {
  docker.send_request_with_query(
    client,
    Post,
    "/auth",
    [],
    option.Some(body),
    option.None,
  )
  |> to_body
}
