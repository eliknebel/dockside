import dockside/docker.{type DockerClient}
import dockside/request_helpers
import gleam/http.{Post}
import gleam/option.{None, Some}

/// # Check auth configuration
///
/// Wraps `POST /auth`.
pub fn check(client: DockerClient, body: String) -> Result(String, String) {
  docker.send_request(client, Post, "/auth", None, Some(body))
  |> request_helpers.expect_body
}
