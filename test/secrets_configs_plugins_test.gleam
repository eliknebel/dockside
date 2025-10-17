import dockside/configs
import dockside/docker.{DockerMock}
import dockside/plugins
import dockside/secrets
import gleam/http.{Delete, Get, Post}
import gleam/http/response
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn configs_list_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(
      path,
      "/configs?filters=%7B%22name%22%3A%5B%22app-config%22%5D%7D",
    )
    Ok(response.Response(status: 200, headers: [], body: "[]"))
  })
  |> configs.list(option.Some("{\"name\":[\"app-config\"]}"))
  |> should.equal(Ok("[]"))
}

pub fn plugins_list_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(
      path,
      "/plugins?filters=%7B%22capability%22%3A%5B%22logging%22%5D%7D",
    )
    Ok(response.Response(status: 200, headers: [], body: "[]"))
  })
  |> plugins.list(option.Some("{\"capability\":[\"logging\"]}"))
  |> should.equal(Ok("[]"))
}

pub fn configs_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/configs/app")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> configs.inspect("app")
  |> should.equal(Ok("{}"))
}

pub fn configs_create_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/configs/create")
    Ok(response.Response(status: 201, headers: [], body: "{\"ID\":\"cfg\"}"))
  })
  |> configs.create("{\"Name\":\"cfg\"}")
  |> should.equal(Ok("{\"ID\":\"cfg\"}"))
}

pub fn configs_update_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/configs/app/update?version=4")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> configs.update("app", 4, "{\"Data\":\"value\"}")
  |> should.equal(Ok(Nil))
}

pub fn configs_remove_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Delete)
    should.equal(path, "/configs/app")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> configs.remove("app")
  |> should.equal(Ok(Nil))
}

pub fn secrets_create_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/secrets/create")
    Ok(response.Response(status: 201, headers: [], body: "{\"ID\":\"secret\"}"))
  })
  |> secrets.create("{\"Name\":\"secret\"}")
  |> should.equal(Ok("{\"ID\":\"secret\"}"))
}

pub fn secrets_list_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/secrets?filters=%7B%22name%22%3A%5B%22secret%22%5D%7D")
    Ok(response.Response(status: 200, headers: [], body: "[]"))
  })
  |> secrets.list(option.Some("{\"name\":[\"secret\"]}"))
  |> should.equal(Ok("[]"))
}

pub fn secrets_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/secrets/secret")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> secrets.inspect("secret")
  |> should.equal(Ok("{}"))
}

pub fn secrets_update_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/secrets/secret/update?version=10")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> secrets.update("secret", 10, "{\"Data\":\"Zm9v\"}")
  |> should.equal(Ok(Nil))
}

pub fn secrets_remove_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Delete)
    should.equal(path, "/secrets/secret")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> secrets.remove("secret")
  |> should.equal(Ok(Nil))
}

pub fn plugins_enable_timeout_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/plugins/log-driver/enable?timeout=60")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> plugins.enable("log-driver", option.Some(60))
  |> should.equal(Ok(Nil))
}

pub fn plugins_disable_force_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/plugins/log-driver/disable?force=true")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> plugins.disable("log-driver", True)
  |> should.equal(Ok(Nil))
}

pub fn plugins_remove_force_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Delete)
    should.equal(path, "/plugins/log-driver?force=false")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> plugins.remove("log-driver", False)
  |> should.equal(Ok(Nil))
}

pub fn plugins_install_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/plugins/pull?remote=foo%2Fbar&name=custom")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> plugins.install("foo/bar", option.Some("custom"), option.None)
  |> should.equal(Ok("{}"))
}

pub fn plugins_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/plugins/foo/json")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> plugins.inspect("foo")
  |> should.equal(Ok("{}"))
}

pub fn plugins_upgrade_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/plugins/foo/upgrade?remote=foo%2Flatest")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> plugins.upgrade("foo", option.Some("foo/latest"), option.None, "{}")
  |> should.equal(Ok("{}"))
}

pub fn plugins_push_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/plugins/foo/push")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> plugins.push("foo")
  |> should.equal(Ok("{}"))
}
