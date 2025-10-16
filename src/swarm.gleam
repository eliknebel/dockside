import docker.{type DockerClient}
import gleam/http.{type Method, Get, Post}
import gleam/http/response
import gleam/option
import gleam/result
import gleam/list
import gleam/int

fn request(
  client: DockerClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  body: option.Option(String),
) -> Result(response.Response(String), docker.DockerError) {
  docker.send_request_with_query(client, method, path, query, body, option.None)
}

fn to_body(
  res: Result(response.Response(String), docker.DockerError),
) -> Result(String, String) {
  res
  |> docker.map_error
  |> result.map(fn(r) { r.body })
}

fn to_nil(
  res: Result(response.Response(String), docker.DockerError),
) -> Result(Nil, String) {
  res
  |> docker.map_error
  |> result.map(fn(_) { Nil })
}

/// # Inspect swarm
///
/// Wraps `GET /swarm`.
pub fn inspect(client: DockerClient) -> Result(String, String) {
  request(client, Get, "/swarm", [], option.None)
  |> to_body
}

/// # Init swarm
///
/// Wraps `POST /swarm/init`.
pub fn init(
  client: DockerClient,
  body: String,
) -> Result(String, String) {
  request(client, Post, "/swarm/init", [], option.Some(body))
  |> to_body
}

/// # Join swarm
///
/// Wraps `POST /swarm/join`.
pub fn join(
  client: DockerClient,
  body: String,
) -> Result(Nil, String) {
  request(client, Post, "/swarm/join", [], option.Some(body))
  |> to_nil
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

/// # Leave swarm
///
/// Wraps `POST /swarm/leave`.
pub fn leave(
  client: DockerClient,
  force: Bool,
) -> Result(Nil, String) {
  request(
    client,
    Post,
    "/swarm/leave",
    [#("force", bool_to_string(force))],
    option.None,
  )
  |> to_nil
}

/// # Unlock key
///
/// Wraps `GET /swarm/unlockkey`.
pub fn unlock_key(client: DockerClient) -> Result(String, String) {
  request(client, Get, "/swarm/unlockkey", [], option.None)
  |> to_body
}

/// # Unlock swarm
///
/// Wraps `POST /swarm/unlock`.
pub fn unlock(
  client: DockerClient,
  body: String,
) -> Result(Nil, String) {
  request(client, Post, "/swarm/unlock", [], option.Some(body))
  |> to_nil
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
      #("rotateManagerToken", bool_to_string(rotate_manager_token)),
    ])
    |> list.append([
      #("rotateWorkerToken", bool_to_string(rotate_worker_token)),
    ])

  request(client, Post, "/swarm/update", query, option.Some(body))
  |> to_nil
}
