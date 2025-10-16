import docker.{type DockerClient}
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{type Method, Delete, Get, Post}
import gleam/http/response
import gleam/json
import gleam/option.{None}
import gleam/result
import gleam/list
import utils
import gleam/uri
import gleam/int

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

pub type LogsOptions {
  LogsOptions(
    stdout: Bool,
    stderr: Bool,
    since: option.Option(Int),
    until: option.Option(Int),
    timestamps: Bool,
    follow: Bool,
    tail: option.Option(String),
    details: Bool,
  )
}

pub fn default_logs_options() -> LogsOptions {
  LogsOptions(
    stdout: True,
    stderr: True,
    since: option.None,
    until: option.None,
    timestamps: False,
    follow: False,
    tail: option.None,
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
  RemoveOptions(
    remove_volumes: Bool,
    force: Bool,
    remove_link: Bool,
  )
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
  |> decode_response_list()
}

fn decode_response_list(
  res: Result(response.Response(String), docker.DockerError),
) {
  case res {
    Ok(r) -> decode_container_list(r.body)
    Error(error) -> Error(docker.humanize_error(error))
  }
}

fn request(
  client: DockerClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  body: option.Option(String),
) -> Result(response.Response(String), docker.DockerError) {
  docker.send_request_with_query(client, method, path, query, body, None)
}

fn container_path(id: String, suffix: String) -> String {
  "/containers/" <> uri.percent_encode(id) <> suffix
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

fn append_optional(
  query: List(#(String, String)),
  key: String,
  value: option.Option(String),
) -> List(#(String, String)) {
  case value {
    option.Some(v) -> list.append(query, [#(key, v)])
    option.None -> query
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn append_bool(
  query: List(#(String, String)),
  key: String,
  value: Bool,
) -> List(#(String, String)) {
  list.append(query, [#(key, bool_to_string(value))])
}

fn int_option_to_string(
  value: option.Option(Int),
) -> option.Option(String) {
  case value {
    option.Some(v) -> option.Some(int.to_string(v))
    option.None -> option.None
  }
}

fn optional_headers(
  headers: List(#(String, String)),
) -> option.Option(List(#(String, String))) {
  case headers {
    [] -> option.None
    _ -> option.Some(headers)
  }
}

/// # Create container
///
/// Wraps `POST /containers/create`.
/// Provide a JSON encoded container configuration in `body`.
pub fn create(
  client: DockerClient,
  body: String,
  name: option.Option(String),
  platform: option.Option(String),
  headers: List(#(String, String)),
) -> Result(String, String) {
  let query =
    []
    |> append_optional("name", name)
    |> append_optional("platform", platform)

  docker.send_request_with_query(
    client,
    Post,
    "/containers/create",
    query,
    option.Some(body),
    optional_headers(headers),
  )
  |> to_body
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
    |> append_optional(
      "size",
      case include_size {
        True -> option.Some("true")
        False -> option.None
      },
    )

  request(client, Get, container_path(id, "/json"), query, option.None)
  |> to_body
}

/// # Display running processes in a container
///
/// Wraps `GET /containers/{id}/top`.
pub fn top(
  client: DockerClient,
  id: String,
  ps_args: option.Option(String),
) -> Result(String, String) {
  let query = [] |> append_optional("ps_args", ps_args)
  request(client, Get, container_path(id, "/top"), query, option.None)
  |> to_body
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
    |> append_bool("stdout", stdout)
    |> append_bool("stderr", stderr)
    |> append_optional("since", int_option_to_string(since))
    |> append_optional("until", int_option_to_string(until_))
    |> append_bool("timestamps", timestamps)
    |> append_bool("follow", follow)
    |> append_optional("tail", tail)
    |> append_bool("details", details)

  request(client, Get, container_path(id, "/logs"), query, option.None)
  |> to_body
}

/// # Inspect filesystem changes
///
/// Wraps `GET /containers/{id}/changes`.
pub fn changes(client: DockerClient, id: String) -> Result(String, String) {
  request(client, Get, container_path(id, "/changes"), [], option.None)
  |> to_body
}

/// # Retrieve container stats
///
/// Wraps `GET /containers/{id}/stats`.
pub fn stats(
  client: DockerClient,
  id: String,
  options: StatsOptions,
) -> Result(String, String) {
  let StatsOptions(stream: stream, one_shot: one_shot, decode: decode) =
    options

  let query =
    []
    |> append_bool("stream", stream)
    |> append_bool("one-shot", one_shot)
    |> append_bool("decode", decode)

  request(client, Get, container_path(id, "/stats"), query, option.None)
  |> to_body
}

/// # Start container
///
/// Wraps `POST /containers/{id}/start`.
pub fn start(
  client: DockerClient,
  id: String,
  detach_keys: option.Option(String),
) -> Result(Nil, String) {
  let query = [] |> append_optional("detachKeys", detach_keys)
  request(client, Post, container_path(id, "/start"), query, option.None)
  |> to_nil
}

/// # Stop container
///
/// Wraps `POST /containers/{id}/stop`.
pub fn stop(
  client: DockerClient,
  id: String,
  timeout_seconds: option.Option(Int),
) -> Result(Nil, String) {
  let query = [] |> append_optional("t", int_option_to_string(timeout_seconds))
  request(client, Post, container_path(id, "/stop"), query, option.None)
  |> to_nil
}

/// # Restart container
///
/// Wraps `POST /containers/{id}/restart`.
pub fn restart(
  client: DockerClient,
  id: String,
  timeout_seconds: option.Option(Int),
) -> Result(Nil, String) {
  let query = [] |> append_optional("t", int_option_to_string(timeout_seconds))
  request(client, Post, container_path(id, "/restart"), query, option.None)
  |> to_nil
}

/// # Update container
///
/// Wraps `POST /containers/{id}/update`.
pub fn update(
  client: DockerClient,
  id: String,
  body: String,
) -> Result(String, String) {
  request(
    client,
    Post,
    container_path(id, "/update"),
    [],
    option.Some(body),
  )
  |> to_body
}

/// # Kill container
///
/// Wraps `POST /containers/{id}/kill`.
pub fn kill(
  client: DockerClient,
  id: String,
  signal: option.Option(String),
) -> Result(Nil, String) {
  let query = [] |> append_optional("signal", signal)
  request(client, Post, container_path(id, "/kill"), query, option.None)
  |> to_nil
}

/// # Resize container TTY
///
/// Wraps `POST /containers/{id}/resize`.
pub fn resize(
  client: DockerClient,
  id: String,
  height: option.Option(Int),
  width: option.Option(Int),
) -> Result(Nil, String) {
  let query =
    []
    |> append_optional("h", int_option_to_string(height))
    |> append_optional("w", int_option_to_string(width))

  request(client, Post, container_path(id, "/resize"), query, option.None)
  |> to_nil
}

/// # Pause container
///
/// Wraps `POST /containers/{id}/pause`.
pub fn pause(client: DockerClient, id: String) -> Result(Nil, String) {
  request(client, Post, container_path(id, "/pause"), [], option.None)
  |> to_nil
}

/// # Unpause container
///
/// Wraps `POST /containers/{id}/unpause`.
pub fn unpause(client: DockerClient, id: String) -> Result(Nil, String) {
  request(client, Post, container_path(id, "/unpause"), [], option.None)
  |> to_nil
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
  request(client, Post, container_path(id, "/rename"), query, option.None)
  |> to_nil
}

/// # Wait for container
///
/// Wraps `POST /containers/{id}/wait`.
pub fn wait(
  client: DockerClient,
  id: String,
  condition: option.Option(String),
) -> Result(String, String) {
  let query = [] |> append_optional("condition", condition)
  request(client, Post, container_path(id, "/wait"), query, option.None)
  |> to_body
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
    |> append_bool("v", remove_volumes)
    |> append_bool("force", force)
    |> append_bool("link", remove_link)

  request(client, Delete, container_path(id, ""), query, option.None)
  |> to_nil
}

/// # Prune containers
///
/// Wraps `POST /containers/prune`.
/// The `filters` parameter should be a JSON encoded string as defined by the Docker Engine API.
pub fn prune(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  let query = [] |> append_optional("filters", filters)
  request(client, Post, "/containers/prune", query, option.None)
  |> to_body
}
