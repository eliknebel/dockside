import dockside/docker.{DockerMock}
import dockside/images
import gleam/http.{Delete, Get, Post}
import gleam/http/response
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn list_test() {
  DockerMock(fn(_method, _path) {
    Ok(response.Response(
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
  |> should.equal(
    Ok([
      images.Image(
        id: "sha256:46331d942d6350436f64e614d75725f6de3bb5c63e266e236e04389820a234c4",
        parent_id: "",
        repo_tags: ["hello-world:latest"],
        repo_digests: option.Some([
          "hello-world@sha256:faa03e786c97f07ef34423fccceeec2398ec8a5759259f94d99078f264e9d7af",
        ]),
        created: 1_647_706_378,
        size: 9136,
        shared_size: -1,
        virtual_size: 9136,
        labels: option.None,
        containers: -1,
      ),
      images.Image(
        id: "sha256:073eff6bf98cd430c8921d86b67e41c42366fe4909668fbc3c824f3e44827353",
        parent_id: "",
        repo_tags: ["postgres:latest"],
        repo_digests: option.None,
        created: 1_644_884_411,
        size: 353_724_805,
        shared_size: -1,
        virtual_size: 353_724_805,
        labels: option.None,
        containers: -1,
      ),
    ]),
  )
}

pub fn inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/images/alpine/json")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> images.inspect("alpine")
  |> should.equal(Ok("{}"))
}

pub fn remove_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Delete)
    should.equal(path, "/images/alpine?force=true&noprune=false")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> images.remove("alpine", images.RemoveOptions(force: True, noprune: False))
  |> should.equal(Ok(Nil))
}

pub fn create_header_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/images/create?fromImage=alpine&tag=latest")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> images.create(
    option.Some("alpine"),
    option.None,
    option.None,
    option.Some("latest"),
    option.None,
    option.None,
  )
  |> should.equal(Ok("{}"))
}
