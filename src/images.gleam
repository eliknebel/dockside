import docker.{type DockerClient}
import gleam/dict
import gleam/dynamic/decode
import gleam/http.{type Method, Delete, Get, Post}
import gleam/http/response
import gleam/json
import gleam/option
import gleam/result
import gleam/list
import gleam/uri
import utils
import gleam/int

pub type Image {
  Image(
    id: String,
    parent_id: String,
    repo_tags: List(String),
    repo_digests: option.Option(List(String)),
    created: Int,
    size: Int,
    shared_size: Int,
    virtual_size: Int,
    labels: option.Option(dict.Dict(String, String)),
    containers: Int,
  )
}

pub type ListOptions {
  ListOptions(
    all: Bool,
    digests: Bool,
    filters: option.Option(String),
  )
}

pub fn default_list_options() -> ListOptions {
  ListOptions(all: False, digests: False, filters: option.None)
}

pub type RemoveOptions {
  RemoveOptions(force: Bool, noprune: Bool)
}

pub fn default_remove_options() -> RemoveOptions {
  RemoveOptions(force: False, noprune: False)
}

fn image_decoder() -> decode.Decoder(Image) {
  use id <- decode.field("Id", decode.string)
  use parent_id <- decode.field("ParentId", decode.string)
  use repo_tags_opt <- decode.optional_field(
    "RepoTags",
    option.None,
    decode.optional(decode.list(decode.string)),
  )
  let repo_tags = option.unwrap(repo_tags_opt, or: [])
  use repo_digests <- decode.optional_field(
    "RepoDigests",
    option.None,
    decode.optional(decode.list(decode.string)),
  )
  use created <- decode.field("Created", decode.int)
  use size <- decode.field("Size", decode.int)
  use shared_size <- decode.field("SharedSize", decode.int)
  use virtual_size <- decode.field("VirtualSize", decode.int)
  use labels <- decode.optional_field(
    "Labels",
    option.None,
    decode.optional(decode.dict(decode.string, decode.string)),
  )
  use containers <- decode.field("Containers", decode.int)

  decode.success(Image(
    id: id,
    parent_id: parent_id,
    repo_tags: repo_tags,
    repo_digests: repo_digests,
    created: created,
    size: size,
    shared_size: shared_size,
    virtual_size: virtual_size,
    labels: labels,
    containers: containers,
  ))
}

fn decode_image_list(body: String) {
  case json.parse(from: body, using: decode.list(image_decoder())) {
    Ok(r) -> Ok(r)
    Error(e) -> Error(utils.prettify_json_decode_error(e))
  }
}

/// # Inspect image
///
/// Wraps `GET /images/{name}/json`.
pub fn inspect(client: DockerClient, name: String) -> Result(String, String) {
  request(
    client,
    Get,
    image_path(name, "/json"),
    [],
    option.None,
    option.None,
  )
  |> to_body
}

/// # Get image history
///
/// Wraps `GET /images/{name}/history`.
pub fn history(client: DockerClient, name: String) -> Result(String, String) {
  request(
    client,
    Get,
    image_path(name, "/history"),
    [],
    option.None,
    option.None,
  )
  |> to_body
}

/// # Remove image
///
/// Wraps `DELETE /images/{name}`.
pub fn remove(
  client: DockerClient,
  name: String,
  options: RemoveOptions,
) -> Result(Nil, String) {
  let RemoveOptions(force: force, noprune: noprune) = options

  let query =
    []
    |> append_bool("force", force)
    |> append_bool("noprune", noprune)

  request(client, Delete, image_path(name, ""), query, option.None, option.None)
  |> to_nil
}

/// # Prune images
///
/// Wraps `POST /images/prune`.
/// The `filters` argument expects a JSON encoded filter string.
pub fn prune(
  client: DockerClient,
  filters: option.Option(String),
) -> Result(String, String) {
  let query = [] |> append_optional("filters", filters)
  request(client, Post, "/images/prune", query, option.None, option.None)
  |> to_body
}

/// # Search images
///
/// Wraps `GET /images/search`.
/// `filters` should be a JSON encoded string of filters as documented by Docker.
pub fn search(
  client: DockerClient,
  term: String,
  limit: option.Option(Int),
  filters: option.Option(String),
) -> Result(String, String) {
  let query =
    []
    |> list.append([#("term", term)])
    |> append_optional("limit", int_option_to_string(limit))
    |> append_optional("filters", filters)

  request(client, Get, "/images/search", query, option.None, option.None)
  |> to_body
}

/// # Create (pull) image
///
/// Wraps `POST /images/create`. Provide at least `from_image` or `from_src`.
pub fn create(
  client: DockerClient,
  from_image: option.Option(String),
  from_src: option.Option(String),
  repo: option.Option(String),
  tag: option.Option(String),
  platform: option.Option(String),
  registry_auth: option.Option(String),
) -> Result(String, String) {
  let query =
    []
    |> append_optional("fromImage", from_image)
    |> append_optional("fromSrc", from_src)
    |> append_optional("repo", repo)
    |> append_optional("tag", tag)
    |> append_optional("platform", platform)

  let headers =
    case registry_auth {
      option.Some(auth) -> option.Some([#("X-Registry-Auth", auth)])
      option.None -> option.None
    }

  request(client, Post, "/images/create", query, option.None, headers)
  |> to_body
}

/// # Push image
///
/// Wraps `POST /images/{name}/push`.
pub fn push(
  client: DockerClient,
  name: String,
  tag: option.Option(String),
  registry_auth: option.Option(String),
) -> Result(String, String) {
  let query = [] |> append_optional("tag", tag)

  let headers =
    case registry_auth {
      option.Some(auth) -> option.Some([#("X-Registry-Auth", auth)])
      option.None -> option.None
    }

  request(
    client,
    Post,
    image_path(name, "/push"),
    query,
    option.None,
    headers,
  )
  |> to_body
}

/// # Tag image
///
/// Wraps `POST /images/{name}/tag`.
pub fn tag(
  client: DockerClient,
  name: String,
  repo: String,
  tag_value: option.Option(String),
) -> Result(Nil, String) {
  let query =
    []
    |> list.append([#("repo", repo)])
    |> append_optional("tag", tag_value)

  request(
    client,
    Post,
    image_path(name, "/tag"),
    query,
    option.None,
    option.None,
  )
  |> to_nil
}


fn request(
  client: DockerClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  body: option.Option(String),
  headers: option.Option(List(#(String, String))),
) -> Result(response.Response(String), docker.DockerError) {
  docker.send_request_with_query(client, method, path, query, body, headers)
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

fn image_path(name: String, suffix: String) -> String {
  "/images/" <> uri.percent_encode(name) <> suffix
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

fn append_bool(
  query: List(#(String, String)),
  key: String,
  value: Bool,
) -> List(#(String, String)) {
  list.append(query, [#(key, bool_to_string(value))])
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn int_option_to_string(
  value: option.Option(Int),
) -> option.Option(String) {
  case value {
    option.Some(v) -> option.Some(int.to_string(v))
    option.None -> option.None
  }
}

/// # List images
///
/// Returns a list of images.
pub fn list(client: DockerClient) {
  list_with_options(client, default_list_options())
}

pub fn list_with_options(
  client: DockerClient,
  options: ListOptions,
) {
  let ListOptions(all: all, digests: digests, filters: filters) = options

  let query =
    []
    |> append_bool("all", all)
    |> append_bool("digests", digests)
    |> append_optional("filters", filters)

  request(client, Get, "/images/json", query, option.None, option.None)
  |> fn(res: Result(response.Response(String), docker.DockerError)) {
    case res {
      Ok(r) -> decode_image_list(r.body)
      Error(error) -> Error(docker.humanize_error(error))
    }
  }
}
