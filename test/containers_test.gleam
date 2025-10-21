import dockside/containers
import dockside/docker.{DockerMock}
import gleam/dict
import gleam/http.{Get, Post}
import gleam/http/response
import gleam/option.{Some}
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
        \"Id\": \"96d581b4903fcf229ca0d3691c118f7ce92e9d444dadf58e9587c7692c5c7505\",
        \"Names\": [\"/eager_satoshi\"],
        \"Image\": \"postgres\",
        \"ImageID\": \"sha256:073eff6bf98cd430c8921d86b67e41c42366fe4909668fbc3c824f3e44827353\",
        \"Command\": \"docker-entrypoint.sh postgres\",
        \"Created\": 1668641292,
        \"State\": \"running\",
        \"Status\": \"Up 4 hours\",
        \"Ports\": [{
          \"PrivatePort\": 5432,
          \"Type\": \"tcp\"
        }],
        \"Labels\": {},
        \"HostConfig\": {
          \"NetworkMode\": \"default\"
        },
        \"Mounts\": [{
          \"Name\": \"c32ea1888b89027230e898fd5d23b0cfb1d812c7fe859429e51c33f1ba56db07\",
          \"Source\": \"\",
          \"Destination\": \"/var/lib/postgresql/data\",
          \"Driver\": \"local\",
          \"Mode\": \"\",
          \"RW\": true,
          \"Propagation\": \"\"
        }]
      }
    ]",
    ))
  })
  |> containers.list()
  |> should.equal(
    Ok([
      containers.Container(
        id: "96d581b4903fcf229ca0d3691c118f7ce92e9d444dadf58e9587c7692c5c7505",
        names: ["/eager_satoshi"],
        image: "postgres",
        image_id: "sha256:073eff6bf98cd430c8921d86b67e41c42366fe4909668fbc3c824f3e44827353",
        command: "docker-entrypoint.sh postgres",
        created: 1_668_641_292,
        state: "running",
        status: "Up 4 hours",
        ports: [
          containers.Port(
            ip: option.None,
            private_port: option.Some(5432),
            public_port: option.None,
            type_: option.Some("tcp"),
          ),
        ],
        labels: dict.new(),
        host_config: containers.HostConfig("default"),
        mounts: [
          containers.Mount(
            Some(
              "c32ea1888b89027230e898fd5d23b0cfb1d812c7fe859429e51c33f1ba56db07",
            ),
            Some(""),
            Some("/var/lib/postgresql/data"),
            Some("local"),
            Some(""),
            True,
            Some(""),
          ),
        ],
        size_rw: option.None,
        size_root_fs: option.None,
        network_settings: option.None,
      ),
    ]),
  )
}

pub fn inspect_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Get)
    should.equal(path, "/containers/example/json?size=true")
    Ok(response.Response(status: 200, headers: [], body: "{}"))
  })
  |> containers.inspect("example", True)
  |> should.equal(Ok("{}"))
}

pub fn start_path_test() {
  DockerMock(fn(method, path) {
    should.equal(method, Post)
    should.equal(path, "/containers/run/start?detachKeys=ctrl-p%2Cctrl-q")
    Ok(response.Response(status: 204, headers: [], body: ""))
  })
  |> containers.start("run", option.Some("ctrl-p,ctrl-q"))
  |> should.equal(Ok(Nil))
}
