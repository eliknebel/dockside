import dockside/docker.{type DockerClient}
import dockside/request_helpers
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post}
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri

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
  Network(d: dynamic.Dynamic)
}

pub type NetworkSettings {
  NetworkSettings(networks: List(Network))
}

pub type Mount {
  Mount(
    name: Option(String),
    source: Option(String),
    destination: Option(String),
    driver: Option(String),
    mode: Option(String),
    rw: Bool,
    propagation: Option(String),
  )
}

pub type LogsOptions {
  LogsOptions(
    stdout: Bool,
    stderr: Bool,
    since: Option(Int),
    until: Option(Int),
    timestamps: Bool,
    follow: Bool,
    tail: Option(String),
    details: Bool,
  )
}

pub fn default_logs_options() -> LogsOptions {
  LogsOptions(
    stdout: True,
    stderr: True,
    since: None,
    until: None,
    timestamps: False,
    follow: False,
    tail: None,
    details: False,
  )
}

pub type StatsOptions {
  StatsOptions(stream: Bool, one_shot: Bool, decode: Bool)
}

pub fn default_stats_options() -> StatsOptions {
  StatsOptions(stream: False, one_shot: False, decode: False)
}

pub type RemoveOptions {
  RemoveOptions(remove_volumes: Bool, force: Bool, remove_link: Bool)
}

pub fn default_remove_options() -> RemoveOptions {
  RemoveOptions(remove_volumes: False, force: False, remove_link: False)
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
    size_rw: Option(Int),
    size_root_fs: Option(Int),
    network_settings: Option(dict.Dict(String, dynamic.Dynamic)),
  )
}

fn port_decoder() -> decode.Decoder(Port) {
  use ip <- decode.optional_field("IP", None, decode.optional(decode.string))
  use private_port <- decode.optional_field(
    "PrivatePort",
    None,
    decode.optional(decode.int),
  )
  use public_port <- decode.optional_field(
    "PublicPort",
    None,
    decode.optional(decode.int),
  )
  use type_ <- decode.optional_field(
    "Type",
    None,
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
  use name <- decode.optional_field(
    "Name",
    None,
    decode.optional(decode.string),
  )
  use source <- decode.optional_field(
    "Source",
    None,
    decode.optional(decode.string),
  )
  use destination <- decode.optional_field(
    "Destination",
    None,
    decode.optional(decode.string),
  )
  use driver <- decode.optional_field(
    "Driver",
    None,
    decode.optional(decode.string),
  )
  use mode <- decode.optional_field(
    "Mode",
    None,
    decode.optional(decode.string),
  )
  use rw <- decode.optional_field("RW", False, decode.bool)
  use propagation <- decode.optional_field(
    "Propagation",
    None,
    decode.optional(decode.string),
  )

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
  use labels <- decode.optional_field(
    "Labels",
    dict.new(),
    decode.dict(decode.string, decode.string),
  )
  use host_config <- decode.field("HostConfig", host_config_decoder())
  use mounts <- decode.optional_field(
    "Mounts",
    [],
    decode.list(mount_decoder()),
  )
  use size_rw <- decode.optional_field(
    "SizeRw",
    None,
    decode.optional(decode.int),
  )
  use size_root_fs <- decode.optional_field(
    "SizeRootFs",
    None,
    decode.optional(decode.int),
  )
  use network_settings <- decode.optional_field(
    "NetworkSettings",
    None,
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

fn decode_container_list(
  body: String,
) -> Result(List(Container), docker.DockerError) {
  case json.parse(from: body, using: decode.list(container_decoder())) {
    Ok(r) -> Ok(r)
    Error(e) -> Error(docker.DecodeError(e))
  }
}

fn decode_response_list(
  res: Result(response.Response(String), docker.DockerError),
) -> Result(List(Container), docker.DockerError) {
  case res {
    Ok(r) -> decode_container_list(r.body)
    Error(error) -> Error(error)
  }
}

fn list_with_query(
  client: DockerClient,
  query: List(#(String, String)),
) -> Result(List(Container), docker.DockerError) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query("/containers/json", query),
    None,
    None,
  )
  |> decode_response_list
}

/// # List containers
///
/// Returns a list of running containers by default.
pub fn list(client: DockerClient) -> Result(List(Container), docker.DockerError) {
  list_with_query(client, [])
}

/// # List all containers
///
/// Returns a list of containers, including those that are stopped.
pub fn list_all(
  client: DockerClient,
) -> Result(List(Container), docker.DockerError) {
  list_with_query(client, request_helpers.append_bool([], "all", True))
}

fn container_path(id: String, suffix: String) -> String {
  "/containers/" <> uri.percent_encode(id) <> suffix
}

/// # Create container
///
/// Wraps `POST /containers/create`.
/// Provide a JSON encoded container configuration in `body`.
pub fn create(
  client: DockerClient,
  body: String,
  name: Option(String),
  platform: Option(String),
  headers: List(#(String, String)),
) -> Result(String, String) {
  let query =
    []
    |> request_helpers.append_optional("name", name)
    |> request_helpers.append_optional("platform", platform)

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query("/containers/create", query),
    request_helpers.optional_headers(headers),
    Some(body),
  )
  |> request_helpers.expect_body
}

/// # Inspect container
///
/// Wraps `GET /containers/{id}/json`.
pub fn inspect(
  client: DockerClient,
  id: String,
  include_size: Bool,
) -> Result(String, String) {
  let query =
    []
    |> request_helpers.append_optional("size", case include_size {
      True -> Some("true")
      False -> None
    })

  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(container_path(id, "/json"), query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Display running processes in a container
///
/// Wraps `GET /containers/{id}/top`.
pub fn top(
  client: DockerClient,
  id: String,
  ps_args: Option(String),
) -> Result(String, String) {
  let query = [] |> request_helpers.append_optional("ps_args", ps_args)
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(container_path(id, "/top"), query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Fetch container logs
///
/// Wraps `GET /containers/{id}/logs`.
pub fn logs(
  client: DockerClient,
  id: String,
  options: LogsOptions,
) -> Result(String, String) {
  let LogsOptions(
    stdout: stdout,
    stderr: stderr,
    since: since,
    until: until_,
    timestamps: timestamps,
    follow: follow,
    tail: tail,
    details: details,
  ) = options

  let query =
    []
    |> request_helpers.append_bool("stdout", stdout)
    |> request_helpers.append_bool("stderr", stderr)
    |> request_helpers.append_optional(
      "since",
      request_helpers.int_option_to_string(since),
    )
    |> request_helpers.append_optional(
      "until",
      request_helpers.int_option_to_string(until_),
    )
    |> request_helpers.append_bool("timestamps", timestamps)
    |> request_helpers.append_bool("follow", follow)
    |> request_helpers.append_optional("tail", tail)
    |> request_helpers.append_bool("details", details)

  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(container_path(id, "/logs"), query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Inspect filesystem changes
///
/// Wraps `GET /containers/{id}/changes`.
pub fn changes(client: DockerClient, id: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(container_path(id, "/changes"), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Retrieve container stats
///
/// Wraps `GET /containers/{id}/stats`.
pub fn stats(
  client: DockerClient,
  id: String,
  options: StatsOptions,
) -> Result(String, String) {
  let StatsOptions(stream: stream, one_shot: one_shot, decode: decode) = options

  let query =
    []
    |> request_helpers.append_bool("stream", stream)
    |> request_helpers.append_bool("one-shot", one_shot)
    |> request_helpers.append_bool("decode", decode)

  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(container_path(id, "/stats"), query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Start container
///
/// Wraps `POST /containers/{id}/start`.
pub fn start(
  client: DockerClient,
  id: String,
  detach_keys: Option(String),
) -> Result(Nil, String) {
  let query = [] |> request_helpers.append_optional("detachKeys", detach_keys)
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/start"), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Stop container
///
/// Wraps `POST /containers/{id}/stop`.
pub fn stop(
  client: DockerClient,
  id: String,
  timeout_seconds: Option(Int),
) -> Result(Nil, String) {
  let query =
    []
    |> request_helpers.append_optional(
      "t",
      request_helpers.int_option_to_string(timeout_seconds),
    )

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/stop"), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Restart container
///
/// Wraps `POST /containers/{id}/restart`.
pub fn restart(
  client: DockerClient,
  id: String,
  timeout_seconds: Option(Int),
) -> Result(Nil, String) {
  let query =
    []
    |> request_helpers.append_optional(
      "t",
      request_helpers.int_option_to_string(timeout_seconds),
    )

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/restart"), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Update container
///
/// Wraps `POST /containers/{id}/update`.
pub fn update(
  client: DockerClient,
  id: String,
  body: String,
) -> Result(String, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/update"), []),
    None,
    Some(body),
  )
  |> request_helpers.expect_body
}

/// # Kill container
///
/// Wraps `POST /containers/{id}/kill`.
pub fn kill(
  client: DockerClient,
  id: String,
  signal: Option(String),
) -> Result(Nil, String) {
  let query = [] |> request_helpers.append_optional("signal", signal)
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/kill"), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Resize container TTY
///
/// Wraps `POST /containers/{id}/resize`.
pub fn resize(
  client: DockerClient,
  id: String,
  height: Option(Int),
  width: Option(Int),
) -> Result(Nil, String) {
  let query =
    []
    |> request_helpers.append_optional(
      "h",
      request_helpers.int_option_to_string(height),
    )
    |> request_helpers.append_optional(
      "w",
      request_helpers.int_option_to_string(width),
    )

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/resize"), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Pause container
///
/// Wraps `POST /containers/{id}/pause`.
pub fn pause(client: DockerClient, id: String) -> Result(Nil, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/pause"), []),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Unpause container
///
/// Wraps `POST /containers/{id}/unpause`.
pub fn unpause(client: DockerClient, id: String) -> Result(Nil, String) {
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/unpause"), []),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Rename container
///
/// Wraps `POST /containers/{id}/rename`.
pub fn rename(
  client: DockerClient,
  id: String,
  new_name: String,
) -> Result(Nil, String) {
  let query = [] |> list.append([#("name", new_name)])
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/rename"), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Wait for container
///
/// Wraps `POST /containers/{id}/wait`.
pub fn wait(
  client: DockerClient,
  id: String,
  condition: Option(String),
) -> Result(String, String) {
  let query = [] |> request_helpers.append_optional("condition", condition)
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(container_path(id, "/wait"), query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Remove container
///
/// Wraps `DELETE /containers/{id}`.
pub fn remove(
  client: DockerClient,
  id: String,
  options: RemoveOptions,
) -> Result(Nil, String) {
  let RemoveOptions(
    remove_volumes: remove_volumes,
    force: force,
    remove_link: remove_link,
  ) = options

  let query =
    []
    |> request_helpers.append_bool("v", remove_volumes)
    |> request_helpers.append_bool("force", force)
    |> request_helpers.append_bool("link", remove_link)

  docker.send_request(
    client,
    Delete,
    request_helpers.path_with_query(container_path(id, ""), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Prune containers
///
/// Wraps `POST /containers/prune`.
/// The `filters` parameter should be a JSON encoded string as defined by the Docker Engine API.
pub fn prune(
  client: DockerClient,
  filters: Option(String),
) -> Result(String, String) {
  let query = [] |> request_helpers.append_optional("filters", filters)
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query("/containers/prune", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}
