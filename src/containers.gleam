import docker.{type DockerClient}
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Get}
import gleam/http/response
import gleam/json
import gleam/option.{None}
import utils

pub type Port {
  Port(
    ip: option.Option(String),
    private_port: option.Option(Int),
    public_port: option.Option(Int),
    type_: option.Option(String),
  )
}

pub type HostConfig {
  HostConfig(network_mode: String)
}

pub type Network {
  Network(d: dynamic.Dynamic)
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
    labels: dict.Dict(String, String),
    host_config: HostConfig,
    mounts: List(Mount),
    size_rw: option.Option(Int),
    size_root_fs: option.Option(Int),
    network_settings: option.Option(dict.Dict(String, dynamic.Dynamic)),
  )
}

fn port_decoder() -> decode.Decoder(Port) {
  use ip <- decode.optional_field(
    "IP",
    option.None,
    decode.optional(decode.string),
  )
  use private_port <- decode.optional_field(
    "PrivatePort",
    option.None,
    decode.optional(decode.int),
  )
  use public_port <- decode.optional_field(
    "PublicPort",
    option.None,
    decode.optional(decode.int),
  )
  use type_ <- decode.optional_field(
    "Type",
    option.None,
    decode.optional(decode.string),
  )

  decode.success(Port(
    ip: ip,
    private_port: private_port,
    public_port: public_port,
    type_: type_,
  ))
}

fn host_config_decoder() -> decode.Decoder(HostConfig) {
  use network_mode <- decode.field("NetworkMode", decode.string)
  decode.success(HostConfig(network_mode))
}

fn mount_decoder() -> decode.Decoder(Mount) {
  use name <- decode.field("Name", decode.string)
  use source <- decode.field("Source", decode.string)
  use destination <- decode.field("Destination", decode.string)
  use driver <- decode.field("Driver", decode.string)
  use mode <- decode.field("Mode", decode.string)
  use rw <- decode.field("RW", decode.bool)
  use propagation <- decode.field("Propagation", decode.string)

  decode.success(Mount(
    name: name,
    source: source,
    destination: destination,
    driver: driver,
    mode: mode,
    rw: rw,
    propagation: propagation,
  ))
}

fn container_decoder() -> decode.Decoder(Container) {
  use id <- decode.field("Id", decode.string)
  use names <- decode.field("Names", decode.list(decode.string))
  use image <- decode.field("Image", decode.string)
  use image_id <- decode.field("ImageID", decode.string)
  use command <- decode.field("Command", decode.string)
  use created <- decode.field("Created", decode.int)
  use state <- decode.field("State", decode.string)
  use status <- decode.field("Status", decode.string)
  use ports <- decode.field("Ports", decode.list(port_decoder()))
  use labels <- decode.field(
    "Labels",
    decode.dict(decode.string, decode.string),
  )
  use host_config <- decode.field("HostConfig", host_config_decoder())
  use mounts <- decode.field("Mounts", decode.list(mount_decoder()))
  use size_rw <- decode.optional_field(
    "SizeRw",
    option.None,
    decode.optional(decode.int),
  )
  use size_root_fs <- decode.optional_field(
    "SizeRootFs",
    option.None,
    decode.optional(decode.int),
  )
  use network_settings <- decode.optional_field(
    "NetworkSettings",
    option.None,
    decode.optional(decode.dict(decode.string, decode.dynamic)),
  )

  decode.success(Container(
    id: id,
    names: names,
    image: image,
    image_id: image_id,
    command: command,
    created: created,
    state: state,
    status: status,
    ports: ports,
    labels: labels,
    host_config: host_config,
    mounts: mounts,
    size_rw: size_rw,
    size_root_fs: size_root_fs,
    network_settings: network_settings,
  ))
}

fn decode_container_list(body: String) {
  case json.parse(from: body, using: decode.list(container_decoder())) {
    Ok(r) -> Ok(r)
    Error(e) -> Error(utils.prettify_json_decode_error(e))
  }
}

/// # List containers
///
/// Returns a list of containers.
pub fn list(client: DockerClient) {
  docker.send_request(client, Get, "/containers/json", None, None)
  |> fn(res: Result(response.Response(String), docker.DockerError)) {
    case res {
      Ok(r) -> decode_container_list(r.body)
      Error(error) -> Error(docker.humanize_error(error))
    }
  }
}
