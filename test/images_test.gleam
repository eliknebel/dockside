import gleeunit
import gleeunit/should
import images.{Image}
import gleam/http/response.{Response}
import docker.{DockerHttpMock}
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn list_test() {
  DockerHttpMock(fn(_method, _path) {
    Ok(Response(
      status: 200,
      headers: [],
      body: "[
        {
            \"Containers\": -1,
            \"Created\": 1647706378,
            \"Id\": \"sha256:46331d942d6350436f64e614d75725f6de3bb5c63e266e236e04389820a234c4\",
            \"Labels\": null,
            \"ParentId\": \"\",
            \"RepoDigests\": [
              \"hello-world@sha256:faa03e786c97f07ef34423fccceeec2398ec8a5759259f94d99078f264e9d7af\"
            ],
            \"RepoTags\": [
              \"hello-world:latest\"
            ],
            \"SharedSize\": -1,
            \"Size\": 9136,
            \"VirtualSize\": 9136
          },
          {
            \"Containers\": -1,
            \"Created\": 1644884411,
            \"Id\": \"sha256:073eff6bf98cd430c8921d86b67e41c42366fe4909668fbc3c824f3e44827353\",
            \"Labels\": null,
            \"ParentId\": \"\",
            \"RepoDigests\": null,
            \"RepoTags\": [
              \"postgres:latest\"
            ],
            \"SharedSize\": -1,
            \"Size\": 353724805,
            \"VirtualSize\": 353724805
          }
      ]",
    ))
  })
  |> images.list()
  |> should.equal(Ok([
    Image(
      id: "sha256:46331d942d6350436f64e614d75725f6de3bb5c63e266e236e04389820a234c4",
      parent_id: "",
      repo_tags: ["hello-world:latest"],
      repo_digests: Some([
        "hello-world@sha256:faa03e786c97f07ef34423fccceeec2398ec8a5759259f94d99078f264e9d7af",
      ]),
      created: 1647706378,
      size: 9136,
      shared_size: -1,
      virtual_size: 9136,
      labels: None,
      containers: -1,
    ),
    Image(
      id: "sha256:073eff6bf98cd430c8921d86b67e41c42366fe4909668fbc3c824f3e44827353",
      parent_id: "",
      repo_tags: ["postgres:latest"],
      repo_digests: None,
      created: 1644884411,
      size: 353724805,
      shared_size: -1,
      virtual_size: 353724805,
      labels: None,
      containers: -1,
    ),
  ]))
}
