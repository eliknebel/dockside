import gleam/option.{Option}
import gleam/http/request.{Request}
import hackney_socket

// Defines a docker connection
pub type Docker {
  DockerHttp(host: String, port: Option(Int), api_version: String)
  DockerSocket(socket_path: String, api_version: String)
}

pub fn local() {
  DockerSocket(socket_path: "/var/run/docker.sock", api_version: "v1.41")
}

pub fn send_request(request: Request(String), d: Docker) {
  case d {
    DockerHttp(host, port, api_version) -> Error(Nil)

    DockerSocket(socket_path, api_version) ->
      Ok(hackney_socket.send_socket(request, socket_path))
  }
}
