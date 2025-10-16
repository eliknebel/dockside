import docker.{type DockerClient}
import gleam/dict
import gleam/dynamic/decode
import gleam/http.{Get}
import gleam/http/response
import gleam/json
import gleam/option.{None}
import utils

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

/// # List images
///
/// Returns a list of images.
pub fn list(client: DockerClient) {
  docker.send_request(client, Get, "/images/json", None, None)
  |> fn(res: Result(response.Response(String), docker.DockerError)) {
    case res {
      Ok(r) -> decode_image_list(r.body)
      Error(error) -> Error(docker.humanize_error(error))
    }
  }
}
