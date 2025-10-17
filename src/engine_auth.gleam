import docker.{type DockerClient}
import gleam/http.{Post}
import gleam/option.{None, Some}
import request_helpers

/// # Check auth configuration
///
/// Wraps `POST /auth`.
pub fn check(client: DockerClient, body: String) -> Result(String, String) {
  docker.send_request(client, Post, "/auth", None, Some(body))
  |> request_helpers.expect_body
}
