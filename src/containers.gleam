import gleam/http.{Get}
import gleam/http/request
import gleam/http/response.{Response}
import gleam/json
import gleam/dynamic.{field, int, string}
import docker.{Docker}
import gleam/hackney
import gleam/io

pub type Container {
  Container(
    id: String,
    names: List(String),
    image: String,
    image_id: String,
    command: String,
    created: Int,
  )
}

fn decode_container_list(s: String) {
  let container_decoder =
    dynamic.decode6(
      Container,
      field("Id", string),
      field("Names", dynamic.list(string)),
      field("Image", string),
      field("ImageID", string),
      field("Command", string),
      field("Created", int),
    )

  case json.decode(from: s, using: dynamic.list(of: container_decoder)) {
    Ok(r) -> Ok(r)
    e ->
      io.debug(e)
      |> fn(_) { Error("decode_container_list error") }
  }
}

/// # List containers
///
/// Returns a list of containers.
pub fn list(d: Docker) {
  request.new()
  |> request.set_method(Get)
  |> request.set_path("/containers/json")
  |> docker.send_request(d)
  |> fn(res: Result(Response(String), hackney.Error)) {
    case res {
      Ok(r) -> decode_container_list(r.body)
      Error(_) -> Error("request error")
    }
  }
}

/// # List images
///
/// Returns a list of images.
pub fn images(d: Docker) {
  request.new()
  |> request.set_method(Get)
  |> request.set_path("/images/json")
  |> docker.send_request(d)
}
