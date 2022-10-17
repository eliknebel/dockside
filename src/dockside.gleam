import gleam/io
import docker
import containers

pub fn main() {
  docker.local()
  |> containers.list()
  |> io.debug()
}
