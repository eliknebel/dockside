import gleam/option.{None, Option, Some}
import gleam/http/request.{Request}
import gleam/hackney
import hackney_socket

// Defines a docker connection
pub type Docker {
  DockerHttp(host: String, port: Option(Int))
  DockerSocket(socket_path: String)
}

pub fn local() {
  DockerSocket(socket_path: "/var/run/docker.sock")
}

pub fn remote(host: String, port: Option(Int)) {
  DockerHttp(host, port)
}

pub fn send_request(request: Request(String), d: Docker) {
  case d {
    DockerHttp(host, port) ->
      hackney.send(
        request
        |> request.set_host(host)
        |> maybe_set_port(port),
      )

    DockerSocket(socket_path) ->
      hackney_socket.send_socket(request, socket_path)
  }
}

fn maybe_set_port(request: Request(String), port: Option(Int)) {
  case port {
    Some(p) -> request.set_port(request, p)
    None -> request
  }
}
