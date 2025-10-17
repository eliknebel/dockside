import docker.{type DockerClient}
import gleam/http.{Get}
import gleam/option.{None}
import gleam/uri
import request_helpers

/// # Inspect distribution image
///
/// Wraps `GET /distribution/{name}/json`.
pub fn inspect(client: DockerClient, name: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    "/distribution/" <> uri.percent_encode(name) <> "/json",
    None,
    None,
  )
  |> request_helpers.expect_body
}
