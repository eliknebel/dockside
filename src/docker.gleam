import gleam/option.{None, Option, Some}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
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

pub type DockerAPIError {
  DockerAPIError(message: String)
}

pub fn send_request(
  request: Request(String),
  d: Docker,
) -> Result(Response(String), DockerAPIError) {
  case d {
    DockerHttp(host, port) ->
      request
      |> request.set_host(host)
      |> maybe_set_port(port)
      |> hackney.send()
      |> result_or_error()

    DockerSocket(socket_path) ->
      hackney_socket.send_socket(request, socket_path)
      |> result_or_error()
  }
}

fn maybe_set_port(request: Request(String), port: Option(Int)) {
  case port {
    Some(p) -> request.set_port(request, p)
    None -> request
  }
}

fn result_or_error(
  r: Result(Response(String), hackney.Error),
) -> Result(Response(String), DockerAPIError) {
  case r {
    Error(hackney.Other(_)) ->
      Error(DockerAPIError(message: "An unknown error occurred"))
    Error(hackney.InvalidUtf8Response) ->
      Error(DockerAPIError(message: "Invalid Utf8 Response"))
    Ok(response) -> Ok(response)
  }
}
