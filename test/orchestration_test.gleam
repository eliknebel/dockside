import dockside/docker.{DockerMock}
import dockside/nodes
import dockside/services
import dockside/swarm
import dockside/tasks
import gleam/http.{Delete, Get, Post}
import gleam/http/response
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn swarm_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/swarm")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> swarm.inspect()
  |> should.equal(Ok("{}"))
}

pub fn swarm_init_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/swarm/init")
    Ok(response.Response(status: 200, headers: [], body: "{\"NodeID\":\"1\"}"))
  })
  |> swarm.init("{\"ListenAddr\":\"0.0.0.0:2377\"}")
  |> should.equal(Ok("{\"NodeID\":\"1\"}"))
}

pub fn swarm_join_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/swarm/join")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> swarm.join("{\"RemoteAddrs\":[\"1.2.3.4:2377\"]}")
  |> should.equal(Ok(Nil))
}

pub fn swarm_leave_force_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/swarm/leave?force=true")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> swarm.leave(True)
  |> should.equal(Ok(Nil))
}

pub fn swarm_unlock_key_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/swarm/unlockkey")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> swarm.unlock_key()
  |> should.equal(Ok("{}"))
}

pub fn swarm_unlock_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/swarm/unlock")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> swarm.unlock("{\"UnlockKey\":\"key\"}")
  |> should.equal(Ok(Nil))
}

pub fn swarm_update_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(
      path,
      "/swarm/update?version=7&rotateManagerToken=true&rotateWorkerToken=false",
    )
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> swarm.update(7, True, False, "{}")
  |> should.equal(Ok(Nil))
}

pub fn services_list_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(
      path,
      "/services?filters=%7B%22mode%22%3A%5B%22replicated%22%5D%7D",
    )
    Ok(response.Response(status: 200, headers: [], body: "[]"))
  })
  |> services.list(option.Some("{\"mode\":[\"replicated\"]}"))
  |> should.equal(Ok("[]"))
}

pub fn services_create_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/services/create")
    Ok(response.Response(status: 201, headers: [], body: "{\"ID\":\"svc\"}"))
  })
  |> services.create("{\"Name\":\"svc\"}", option.None)
  |> should.equal(Ok("{\"ID\":\"svc\"}"))
}

pub fn services_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/services/my%2Fsvc")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> services.inspect("my/svc")
  |> should.equal(Ok("{}"))
}

pub fn services_update_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(
      path,
      "/services/api%2Fsvc/update?version=3&registryAuthFrom=secret&rollback=previous",
    )
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> services.update(
    "api/svc",
    3,
    option.Some("auth"),
    option.Some("secret"),
    option.Some("previous"),
    "{\"Name\":\"api\"}",
  )
  |> should.equal(Ok(Nil))
}

pub fn services_logs_options_test() {
  let options =
    services.LogsOptions(
      follow: True,
      stdout: True,
      stderr: False,
      since: option.Some(42),
      timestamps: True,
      tail: option.Some("10"),
      details: False,
    )

  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(
      path,
      "/services/logger/logs?follow=true&stdout=true&stderr=false&since=42&timestamps=true&tail=10&details=false",
    )
    Ok(response.Response(status: 200, headers: [], body: "LOGS"))
  })
  |> services.logs("logger", options)
  |> should.equal(Ok("LOGS"))
}

pub fn services_remove_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Delete)
    should.equal(path, "/services/cleanup")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> services.remove("cleanup")
  |> should.equal(Ok(Nil))
}

pub fn tasks_list_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/tasks?filters=%7B%22node%22%3A%5B%22node-1%22%5D%7D")
    Ok(response.Response(status: 200, headers: [], body: "[]"))
  })
  |> tasks.list(option.Some("{\"node\":[\"node-1\"]}"))
  |> should.equal(Ok("[]"))
}

pub fn tasks_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/tasks/task-1")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> tasks.inspect("task-1")
  |> should.equal(Ok("{}"))
}

pub fn nodes_update_query_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/nodes/node-1/update?version=5")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> nodes.update("node-1", 5, "{\"Role\":\"manager\"}")
  |> should.equal(Ok(Nil))
}

pub fn nodes_remove_force_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Delete)
    should.equal(path, "/nodes/node-1?force=false")
    Ok(response.Response(status: 200, headers: [], body: ""))
  })
  |> nodes.remove("node-1", False)
  |> should.equal(Ok(Nil))
}

pub fn nodes_list_filters_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/nodes?filters=%7B%22role%22%3A%5B%22manager%22%5D%7D")
    Ok(response.Response(status: 200, headers: [], body: "[]"))
  })
  |> nodes.list(option.Some("{\"role\":[\"manager\"]}"))
  |> should.equal(Ok("[]"))
}

pub fn nodes_inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/nodes/node-1")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> nodes.inspect("node-1")
  |> should.equal(Ok("{}"))
}
