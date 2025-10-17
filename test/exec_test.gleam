import dockside/docker.{DockerMock}
import dockside/exec
import gleam/http.{Get, Post}
import gleam/http/response
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn create_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/containers/container%2Fid/exec")
    Ok(response.Response(status: 201, headers: [], body: "{\"Id\":\"exec-1\"}"))
  })
  |> exec.create("container/id", "{\"Cmd\":[\"ls\"]}")
  |> should.equal(Ok("{\"Id\":\"exec-1\"}"))
}

pub fn start_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/exec/exec-1/start")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> exec.start("exec-1", "{\"Detach\":true}")
  |> should.equal(Ok(""))
}

pub fn resize_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/exec/exec-1/resize?h=24&w=80")
    Ok(response.Response(status: 201, headers: [], body: ""))
  })
  |> exec.resize("exec-1", option.Some(24), option.Some(80))
  |> should.equal(Ok(Nil))
}

pub fn inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/exec/exec-1/json")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> exec.inspect("exec-1")
  |> should.equal(Ok("{}"))
}
