import gleam/io
import docker
// import containers
import images

pub fn main() {
  docker.local()
  // |> containers.list()
  |> images.list()
  |> io.debug()
}
