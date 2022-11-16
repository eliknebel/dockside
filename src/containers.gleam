import gleam/http.{Get}
import gleam/http/request
import gleam/http/response.{Response}
import gleam/json
import gleam/dynamic.{Dynamic, bool, field, int, string}
import docker.{Docker, DockerAPIError}
import gleam/io
import gleam/map.{Map}
import gleam/option.{Option}
import decoders.{optional_field}

pub opaque type Port {
  Port(
    ip: Option(String),
    private_port: Option(Int),
    public_port: Option(Int),
    type_: Option(String),
  )
}

pub opaque type HostConfig {
  HostConfig(network_mode: String)
}

// pub opaque type Network {
//   Network(d: Dynamic)
// }

// pub opaque type NetworkSettings {
//   NetworkSettings(networks: List(Network))
// }

pub opaque type Mount {
  Mount(
    name: String,
    source: String,
    destination: String,
    driver: String,
    mode: String,
    rw: Bool,
    propagation: String,
  )
}

pub opaque type Container {
  Container(
    id: String,
    names: List(String),
    image: String,
    image_id: String,
    command: String,
    created: Int,
    state: String,
    status: String,
    ports: List(Port),
    labels: Map(String, String),
    size_rw: Option(Int),
    size_root_fs: Option(Int),
    host_config: HostConfig,
    // network_settings: Map(String, Dynamic),
    mounts: List(Mount),
  )
}

fn decode_container_list(s: String) {
  let port_decoder =
    dynamic.decode4(
      Port,
      optional_field("IP", string),
      optional_field("PrivatePort", int),
      optional_field("PublicPort", int),
      optional_field("Type", string),
    )

  let host_config_decoder = fn(x: Dynamic) {
    case field("NetworkMode", string)(x) {
      Ok(network_mode) -> Ok(HostConfig(network_mode))
      Error(e) -> Error(e)
    }
  }

  // let network_settings_decoder = fn(x: Dynamic) {
  //   case field("NetworkSettings", dynamic.map(string, dynamic.dynamic))(x) {
  //     Ok(network_settings) -> Ok(network_settings)
  //     Error(e) -> Error(e)
  //   }
  // }
  let mount_decoder =
    dynamic.decode7(
      Mount,
      field("Name", string),
      field("Source", string),
      field("Destination", string),
      field("Driver", string),
      field("Mode", string),
      field("RW", bool),
      field("Propagation", string),
    )

  let container_decoder =
    decoders.decode14(
      Container,
      field("Id", string),
      field("Names", dynamic.list(string)),
      field("Image", string),
      field("ImageID", string),
      field("Command", string),
      field("Created", int),
      field("State", string),
      field("Status", string),
      field("Ports", dynamic.list(port_decoder)),
      field("Labels", dynamic.map(string, string)),
      optional_field("SizeRw", int),
      optional_field("SizeRootFs", int),
      field("HostConfig", host_config_decoder),
      // field("NetworkSettings", network_settings_decoder),
      field("Mounts", dynamic.list(mount_decoder)),
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
