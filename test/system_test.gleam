import distribution
import docker.{DockerMock}
import engine_auth
import gleam/http.{Get, Post}
import gleam/http/response
import gleeunit
import gleeunit/should
import system

pub fn main() {
  gleeunit.main()
}

pub fn ping_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/system/ping")
    Ok(response.Response(status: 200, headers: [], body: "pong"))
  })
  |> system.ping()
  |> should.equal(Ok("pong"))
}

pub fn info_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/system/info")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> system.info()
  |> should.equal(Ok("{}"))
}

pub fn version_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/version")
    Ok(response.Response(status: 200, headers: [], body: "{\"Version\":\"25.0\"}"))
  })
  |> system.version()
  |> should.equal(Ok("{\"Version\":\"25.0\"}"))
}

pub fn df_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/system/df")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> system.df()
  |> should.equal(Ok("{}"))
}

pub fn events_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/events?since=100&until=200")
    Ok(response.Response(status: 200, headers: [], body: "[]"))
  })
  |> system.events(
    [
      #("since", "100"),
      #("until", "200"),
    ],
  )
  |> should.equal(Ok("[]"))
}

pub fn prune_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/system/prune")
    Ok(response.Response(status: 200, headers: [], body: "{\"SpaceReclaimed\":0}"))
  })
  |> system.prune()
  |> should.equal(Ok("{\"SpaceReclaimed\":0}"))
}

pub fn distribution_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/distribution/library%2Falpine/json")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> distribution.inspect("library/alpine")
  |> should.equal(Ok("{}"))
}

pub fn auth_check_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/auth")
    Ok(response.Response(status: 200, headers: [], body: "{\"Status\":\"Login Succeeded\"}"))
  })
  |> engine_auth.check("{\"username\":\"test\"}")
  |> should.equal(Ok("{\"Status\":\"Login Succeeded\"}"))
}
