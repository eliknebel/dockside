import gleeunit
import gleeunit/should
import gleam/map
import containers.{Container, HostConfig, Mount, Port}
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
  |> should.equal(Ok([
    Container(
      id: "96d581b4903fcf229ca0d3691c118f7ce92e9d444dadf58e9587c7692c5c7505",
      names: ["/eager_satoshi"],
      image: "postgres",
      image_id: "sha256:073eff6bf98cd430c8921d86b67e41c42366fe4909668fbc3c824f3e44827353",
      command: "docker-entrypoint.sh postgres",
      created: 1668641292,
      state: "running",
      status: "Up 4 hours",
      ports: [Port(None, Some(5432), None, Some("tcp"))],
      labels: map.new(),
      host_config: HostConfig("default"),
      mounts: [
        Mount(
          "c32ea1888b89027230e898fd5d23b0cfb1d812c7fe859429e51c33f1ba56db07",
          "",
          "/var/lib/postgresql/data",
          "local",
          "",
          True,
          "",
        ),
      ],
      size_rw: None,
      size_root_fs: None,
      network_settings: None,
    ),
  ]))
}
