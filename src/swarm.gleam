import docker.{type DockerClient}
import gleam/http.{Get, Post}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import request_helpers

/// # Inspect swarm
///
/// Wraps `GET /swarm`.
pub fn inspect(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/swarm", None, None)
  |> request_helpers.expect_body
}

/// # Init swarm
///
/// Wraps `POST /swarm/init`.
pub fn init(client: DockerClient, body: String) -> Result(String, String) {
  docker.send_request(client, Post, "/swarm/init", None, Some(body))
  |> request_helpers.expect_body
}

/// # Join swarm
///
/// Wraps `POST /swarm/join`.
pub fn join(client: DockerClient, body: String) -> Result(Nil, String) {
  docker.send_request(client, Post, "/swarm/join", None, Some(body))
  |> request_helpers.expect_nil
}

/// # Leave swarm
///
/// Wraps `POST /swarm/leave`.
pub fn leave(client: DockerClient, force: Bool) -> Result(Nil, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query("/swarm/leave", [
      #("force", request_helpers.bool_to_string(force)),
    ]),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Unlock key
///
/// Wraps `GET /swarm/unlockkey`.
pub fn unlock_key(client: DockerClient) -> Result(String, String) {
  docker.send_request(client, Get, "/swarm/unlockkey", None, None)
  |> request_helpers.expect_body
}

/// # Unlock swarm
///
/// Wraps `POST /swarm/unlock`.
pub fn unlock(client: DockerClient, body: String) -> Result(Nil, String) {
  docker.send_request(client, Post, "/swarm/unlock", None, Some(body))
  |> request_helpers.expect_nil
}

/// # Update swarm
///
/// Wraps `POST /swarm/update`.
pub fn update(
  client: DockerClient,
  version: Int,
  rotate_manager_token: Bool,
  rotate_worker_token: Bool,
  body: String,
) -> Result(Nil, String) {
  let query =
    []
    |> list.append([#("version", int.to_string(version))])
    |> list.append([
      #(
        "rotateManagerToken",
        request_helpers.bool_to_string(rotate_manager_token),
      ),
    ])
    |> list.append([
      #(
        "rotateWorkerToken",
        request_helpers.bool_to_string(rotate_worker_token),
      ),
    ])

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query("/swarm/update", query),
    None,
    Some(body),
  )
  |> request_helpers.expect_nil
}
