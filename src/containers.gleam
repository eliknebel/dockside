import gleam/http.{Get}
import gleam/http/request
import docker.{Docker}

pub type Container {
  Container
}

/// # List containers
///
/// Returns a list of containers.
pub fn list(d: Docker) {
  request.new()
  |> request.set_method(Get)
  |> request.set_path("/images/json")
  |> docker.send_request(d)
}
