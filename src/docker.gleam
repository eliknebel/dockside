import gleam/option.{None, Option, Some}
import gleam/string
import gleam/http.{Method}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/hackney
import hackney_socket

const api_version = "v1.41"

// Defines a docker connection
pub type Docker {
  DockerSocket(socket_path: String)
  DockerHttp(host: String, port: Option(Int))
  DockerHttpMock(
    mock_fn: fn(Method, String) -> Result(Response(String), DockerAPIError),
  )
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
  d: Docker,
  method: Method,
  path: String,
) -> Result(Response(String), DockerAPIError) {
  case d {
    DockerHttp(host, port) ->
      request.new()
      |> request.set_method(method)
      |> request.set_path(string.concat(["/", api_version, path]))
      |> request.set_host(host)
      |> maybe_set_port(port)
      |> hackney.send()
      |> result_or_error()

    DockerSocket(socket_path) ->
      request.new()
      |> request.set_method(method)
      |> request.set_path(string.concat(["/", api_version, path]))
      |> hackney_socket.send_socket(socket_path)
      |> result_or_error()

    // used for unit tests
    DockerHttpMock(mock_fn) -> mock_fn(method, path)
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
      Error(DockerAPIError(message: "Invalid UTF-8 Response"))
    Ok(response) -> Ok(response)
  }
}
