import gleam/http.{Get}
import gleam/http/response.{Response}
import gleam/json
import gleam/dynamic.{Dynamic, bool, field, int, string}
import docker.{Docker, DockerAPIError}
import gleam/map.{Map}
import gleam/option.{Option}
import decoders.{optional_field}
import utils.{prettify_json_decode_error}

pub type Port {
  Port(
    ip: Option(String),
    private_port: Option(Int),
    public_port: Option(Int),
    type_: Option(String),
  )
}

pub type HostConfig {
  HostConfig(network_mode: String)
}

pub type Network {
  Network(d: Dynamic)
}

pub type NetworkSettings {
  NetworkSettings(networks: List(Network))
}

pub type Mount {
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

pub type Container {
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
    host_config: HostConfig,
    mounts: List(Mount),
    size_rw: Option(Int),
    size_root_fs: Option(Int),
    network_settings: Option(Map(String, Dynamic)),
  )
}

fn port_decoder() {
  dynamic.decode4(
    Port,
    optional_field("IP", string),
    optional_field("PrivatePort", int),
    optional_field("PublicPort", int),
    optional_field("Type", string),
  )
}

fn host_config_decoder() {
  fn(x: Dynamic) {
    case field("NetworkMode", string)(x) {
      Ok(network_mode) -> Ok(HostConfig(network_mode))
      Error(e) -> Error(e)
    }
  }
}

fn mount_decoder() {
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
}

fn network_settings_decoder() {
  fn(x: Dynamic) {
    case field("NetworkSettings", dynamic.map(string, dynamic.dynamic))(x) {
      Ok(network_settings) -> Ok(network_settings)
      Error(e) -> Error(e)
    }
  }
}

fn container_decoder() {
  decoders.decode15(
    Container,
    field("Id", string),
    field("Names", dynamic.list(string)),
    field("Image", string),
    field("ImageID", string),
    field("Command", string),
    field("Created", int),
    field("State", string),
    field("Status", string),
    field("Ports", dynamic.list(port_decoder())),
    field("Labels", dynamic.map(string, string)),
    field("HostConfig", host_config_decoder()),
    field("Mounts", dynamic.list(mount_decoder())),
    optional_field("SizeRw", int),
    optional_field("SizeRootFs", int),
    optional_field("NetworkSettings", network_settings_decoder()),
  )
}

fn decode_container_list(body: String) {
  case json.decode(body, dynamic.list(of: container_decoder())) {
    Ok(r) -> Ok(r)
    Error(e) -> Error(prettify_json_decode_error(e))
  }
}

/// # List containers
///
/// Returns a list of containers.
pub fn list(d: Docker) {
  docker.send_request(d, Get, "/containers/json")
  |> fn(res: Result(Response(String), DockerAPIError)) {
    case res {
      Ok(r) -> decode_container_list(r.body)
      Error(DockerAPIError(m)) -> Error(m)
    }
  }
}
