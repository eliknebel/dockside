import gleam/http.{Get}
import gleam/http/response.{Response}
import gleam/json
import gleam/dynamic.{field, int, string}
import docker.{Docker, DockerAPIError}
import gleam/map.{Map}
import gleam/option.{Option}
import decoders
import utils.{prettify_json_decode_error}

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
    labels: Option(Map(String, String)),
    containers: Int,
  )
}

fn image_decoder() {
  decoders.decode10(
    Image,
    field("Id", string),
    field("ParentId", string),
    field("RepoTags", dynamic.list(string)),
    field("RepoDigests", dynamic.optional(dynamic.list(string))),
    field("Created", int),
    field("Size", int),
    field("SharedSize", int),
    field("VirtualSize", int),
    field("Labels", dynamic.optional(dynamic.map(string, string))),
    field("Containers", int),
  )
}

fn decode_image_list(body: String) {
  case json.decode(body, dynamic.list(of: image_decoder())) {
    Ok(r) -> Ok(r)
    Error(e) -> Error(prettify_json_decode_error(e))
  }
}

/// # List images
///
/// Returns a list of images.
pub fn list(d: Docker) {
  docker.send_request(d, Get, "/images/json")
  |> fn(res: Result(Response(String), DockerAPIError)) {
    case res {
      Ok(r) -> decode_image_list(r.body)
      Error(DockerAPIError(m)) -> Error(m)
    }
  }
}
