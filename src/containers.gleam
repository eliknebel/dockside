import gleam/http.{Get}
import gleam/http/request
import gleam/http/response.{Response}
import gleam/json
import gleam/dynamic.{field, int, string}
import docker.{Docker, DockerAPIError}
import gleam/io
import gleam/map.{Map}
import utils

pub opaque type Port {
  Port(ip: String, private_port: Int, public_port: Int, type_: String)
}

pub opaque type Container {
  Container(
    id: String,
    names: List(String),
    image: String,
    image_id: String,
    command: String,
    created: Int,
    ports: List(Port),
    labels: Map(String, String),
    state: String,
    status: String,
  )
}

fn decode_container_list(s: String) {
  let port_decoder =
    dynamic.decode4(
      Port,
      field("IP", string),
      field("PrivatePort", int),
      field("PublicPort", int),
      field("Type", string),
    )

  let container_decoder =
    utils.decode10(
      Container,
      field("Id", string),
      field("Names", dynamic.list(string)),
      field("Image", string),
      field("ImageID", string),
      field("Command", string),
      field("Created", int),
      field("Ports", dynamic.list(port_decoder)),
      field("Labels", dynamic.map(string, string)),
      field("State", string),
      field("Status", string),
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
  |> fn(res: Result(Response(String), DockerAPIError)) {
    case res {
      Ok(r) -> decode_container_list(r.body)
      Error(DockerAPIError(m)) -> Error(m)
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
