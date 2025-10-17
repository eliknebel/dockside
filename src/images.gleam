import docker.{type DockerClient}
import gleam/dict
import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some, unwrap as option_unwrap}
import gleam/uri
import request_helpers
import utils

pub type Image {
  Image(
    id: String,
    parent_id: String,
    repo_tags: List(String),
    repo_digests: Option(List(String)),
    created: Int,
    size: Int,
    shared_size: Int,
    virtual_size: Int,
    labels: Option(dict.Dict(String, String)),
    containers: Int,
  )
}

pub type ListOptions {
  ListOptions(all: Bool, digests: Bool, filters: Option(String))
}

pub fn default_list_options() -> ListOptions {
  ListOptions(all: False, digests: False, filters: None)
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
    None,
    decode.optional(decode.list(decode.string)),
  )
  let repo_tags = option_unwrap(repo_tags_opt, or: [])
  use repo_digests <- decode.optional_field(
    "RepoDigests",
    None,
    decode.optional(decode.list(decode.string)),
  )
  use created <- decode.field("Created", decode.int)
  use size <- decode.field("Size", decode.int)
  use shared_size <- decode.field("SharedSize", decode.int)
  use virtual_size <- decode.field("VirtualSize", decode.int)
  use labels <- decode.optional_field(
    "Labels",
    None,
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
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(image_path(name, "/json"), []),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Get image history
///
/// Wraps `GET /images/{name}/history`.
pub fn history(client: DockerClient, name: String) -> Result(String, String) {
  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query(image_path(name, "/history"), []),
    None,
    None,
  )
  |> request_helpers.expect_body
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
    |> request_helpers.append_bool("force", force)
    |> request_helpers.append_bool("noprune", noprune)

  docker.send_request(
    client,
    Delete,
    request_helpers.path_with_query(image_path(name, ""), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

/// # Prune images
///
/// Wraps `POST /images/prune`.
/// The `filters` argument expects a JSON encoded filter string.
pub fn prune(
  client: DockerClient,
  filters: Option(String),
) -> Result(String, String) {
  let query = [] |> request_helpers.append_optional("filters", filters)
  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query("/images/prune", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Search images
///
/// Wraps `GET /images/search`.
/// `filters` should be a JSON encoded string of filters as documented by Docker.
pub fn search(
  client: DockerClient,
  term: String,
  limit: Option(Int),
  filters: Option(String),
) -> Result(String, String) {
  let query =
    []
    |> list.append([#("term", term)])
    |> request_helpers.append_optional(
      "limit",
      request_helpers.int_option_to_string(limit),
    )
    |> request_helpers.append_optional("filters", filters)

  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query("/images/search", query),
    None,
    None,
  )
  |> request_helpers.expect_body
}

/// # Create (pull) image
///
/// Wraps `POST /images/create`. Provide at least `from_image` or `from_src`.
pub fn create(
  client: DockerClient,
  from_image: Option(String),
  from_src: Option(String),
  repo: Option(String),
  tag: Option(String),
  platform: Option(String),
  registry_auth: Option(String),
) -> Result(String, String) {
  let query =
    []
    |> request_helpers.append_optional("fromImage", from_image)
    |> request_helpers.append_optional("fromSrc", from_src)
    |> request_helpers.append_optional("repo", repo)
    |> request_helpers.append_optional("tag", tag)
    |> request_helpers.append_optional("platform", platform)

  let headers = case registry_auth {
    Some(auth) -> Some([#("X-Registry-Auth", auth)])
    None -> None
  }

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query("/images/create", query),
    headers,
    None,
  )
  |> request_helpers.expect_body
}

/// # Push image
///
/// Wraps `POST /images/{name}/push`.
pub fn push(
  client: DockerClient,
  name: String,
  tag: Option(String),
  registry_auth: Option(String),
) -> Result(String, String) {
  let query = [] |> request_helpers.append_optional("tag", tag)

  let headers = case registry_auth {
    Some(auth) -> Some([#("X-Registry-Auth", auth)])
    None -> None
  }

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(image_path(name, "/push"), query),
    headers,
    None,
  )
  |> request_helpers.expect_body
}

/// # Tag image
///
/// Wraps `POST /images/{name}/tag`.
pub fn tag(
  client: DockerClient,
  name: String,
  repo: String,
  tag_value: Option(String),
) -> Result(Nil, String) {
  let query =
    []
    |> list.append([#("repo", repo)])
    |> request_helpers.append_optional("tag", tag_value)

  docker.send_request(
    client,
    Post,
    request_helpers.path_with_query(image_path(name, "/tag"), query),
    None,
    None,
  )
  |> request_helpers.expect_nil
}

fn image_path(name: String, suffix: String) -> String {
  "/images/" <> uri.percent_encode(name) <> suffix
}

/// # List images
///
/// Returns a list of images.
pub fn list(client: DockerClient) {
  list_with_options(client, default_list_options())
}

pub fn list_with_options(client: DockerClient, options: ListOptions) {
  let ListOptions(all: all, digests: digests, filters: filters) = options

  let query =
    []
    |> request_helpers.append_bool("all", all)
    |> request_helpers.append_bool("digests", digests)
    |> request_helpers.append_optional("filters", filters)

  docker.send_request(
    client,
    Get,
    request_helpers.path_with_query("/images/json", query),
    None,
    None,
  )
  |> fn(res) {
    case res {
      Ok(r) -> decode_image_list(r.body)
      Error(error) -> Error(docker.humanize_error(error))
    }
  }
}
