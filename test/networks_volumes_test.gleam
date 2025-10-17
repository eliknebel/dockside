import dockside/docker.{DockerMock}
import dockside/networks
import dockside/volumes
import gleam/http.{Delete, Get, Post}
import gleam/http/response
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn networks_list_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(
      path,
      "/networks?filters=%7B%22name%22%3A%5B%22bridge%22%5D%7D",
    )
    Ok(response.Response(status: 200, headers: [], body: "[]"))
  })
  |> networks.list(option.Some("{\"name\":[\"bridge\"]}"))
  |> should.equal(Ok("[]"))
}

pub fn networks_connect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/networks/net%2Fid/connect")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> networks.connect("net/id", "{\"Container\":\"abc\"}")
  |> should.equal(Ok(Nil))
}

pub fn networks_create_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/networks/create")
    Ok(response.Response(status: 201, headers: [], body: "{\"Id\":\"net\"}"))
  })
  |> networks.create("{\"Name\":\"net\"}")
  |> should.equal(Ok("{\"Id\":\"net\"}"))
}

pub fn networks_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/networks/net-1")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> networks.inspect("net-1")
  |> should.equal(Ok("{}"))
}

pub fn networks_remove_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Delete)
    should.equal(path, "/networks/net-1")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> networks.remove("net-1")
  |> should.equal(Ok(Nil))
}

pub fn networks_prune_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(
      path,
      "/networks/prune?filters=%7B%22dangling%22%3A%5B%22true%22%5D%7D",
    )
    Ok(response.Response(
      status: 200,
      headers: [],
      body: "{\"NetworksDeleted\":[]}",
    ))
  })
  |> networks.prune(option.Some("{\"dangling\":[\"true\"]}"))
  |> should.equal(Ok("{\"NetworksDeleted\":[]}"))
}

pub fn volumes_list_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(
      path,
      "/volumes?filters=%7B%22dangling%22%3A%5B%22true%22%5D%7D",
    )
    Ok(response.Response(status: 200, headers: [], body: "{\"Volumes\":[]}"))
  })
  |> volumes.list(option.Some("{\"dangling\":[\"true\"]}"))
  |> should.equal(Ok("{\"Volumes\":[]}"))
}

pub fn volumes_remove_force_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Delete)
    should.equal(path, "/volumes/cache?force=true")
    Ok(response.Response(status: 204, headers: [], body: ""))
  })
  |> volumes.remove("cache", True)
  |> should.equal(Ok(Nil))
}

pub fn volumes_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/volumes/data")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> volumes.inspect("data")
  |> should.equal(Ok("{}"))
}

pub fn volumes_create_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/volumes/create")
    Ok(response.Response(status: 201, headers: [], body: "{\"Name\":\"data\"}"))
  })
  |> volumes.create("{\"Name\":\"data\"}")
  |> should.equal(Ok("{\"Name\":\"data\"}"))
}

pub fn volumes_prune_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(
      path,
      "/volumes/prune?filters=%7B%22label%22%3A%5B%22env%3Ddev%22%5D%7D",
    )
    Ok(response.Response(
      status: 200,
      headers: [],
      body: "{\"VolumesDeleted\":[]}",
    ))
  })
  |> volumes.prune(option.Some("{\"label\":[\"env=dev\"]}"))
  |> should.equal(Ok("{\"VolumesDeleted\":[]}"))
}
