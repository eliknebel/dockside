import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/http.{type Method}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response, Response}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

import gleam/hackney.{InvalidUtf8Response}
import gleam/json

pub const api_version = "v1.51"

pub const linux_default_socket = "/var/run/docker.sock"

// Defines a docker connection
pub type DockerClient {
  DockerSocket(socket_path: String)
  DockerHttp(host: String, port: Option(Int))
  DockerMock(mock_fn: MockFn)
}

pub fn local() {
  DockerSocket(socket_path: linux_default_socket)
}

pub fn remote(host: String, port: Option(Int)) {
  DockerHttp(host, port)
}

pub type DockerError {
  InvalidUrl(String)
  Http(hackney.Error)
  UnexpectedStatus(Int, String)
  DecodeError(json.DecodeError)
  SocketNotFound(String)
  UnknownError(String)
}

type MockFn =
  fn(Method, String) -> Result(Response(String), DockerError)

pub fn send_request(
  client: DockerClient,
  method: Method,
  path: String,
  body: Option(String),
  headers: Option(List(#(String, String))),
) -> Result(Response(String), DockerError) {
  case client {
    DockerHttp(host, port) -> {
      request.new()
      |> request.set_method(method)
      |> request.set_path(string.concat(["/", api_version, path]))
      |> request.set_host(host)
      |> request.set_header("Content-Type", "application/json")
      |> maybe_apply_headers(headers)
      |> maybe_set_body(body)
      |> maybe_set_port(port)
      |> hackney.send()
      |> result_or_error()
      |> ensure_success_or_error()
}

    DockerSocket(socket_path) -> {
      request.new()
      |> request.set_method(method)
      |> request.set_path(string.concat(["/", api_version, path]))
      |> request.set_header("Content-Type", "application/json")
      |> maybe_apply_headers(headers)
      |> maybe_set_body(body)
      |> socket_send(socket_path)
      |> result_or_error()
      |> ensure_success_or_error()
}

    // used for unit tests
    DockerMock(mock_fn) -> mock_fn(method, path)
  }
}

pub fn build_path(path: String, query: List(#(String, String))) -> String {
  case query {
    [] -> path
    _ -> path <> "?" <> encode_query(query)
  }
}

pub fn encode_query(query: List(#(String, String))) -> String {
  query
  |> list.map(fn(pair) {
    uri.percent_encode(pair.0) <> "=" <> uri.percent_encode(pair.1)
  })
  |> string.join("&")
}

pub fn send_request_with_query(
  client: DockerClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  body: Option(String),
  headers: Option(List(#(String, String))),
) -> Result(Response(String), DockerError) {
  let full_path = build_path(path, query)
  send_request(client, method, full_path, body, headers)
}

pub fn map_error(result: Result(a, DockerError)) -> Result(a, String) {
  case result {
    Ok(value) -> Ok(value)
    Error(error) -> Error(humanize_error(error))
  }
}

fn ensure_success(
  response: Response(String),
) -> Result(Response(String), DockerError) {
  case response.status {
    status if status >= 200 && status < 300 -> Ok(response)
    status -> Error(UnexpectedStatus(status, response.body))
  }
}

fn ensure_success_or_error(
  result: Result(Response(String), DockerError),
) -> Result(Response(String), DockerError) {
  case result {
    Ok(response) -> ensure_success(response)
    Error(error) -> Error(error)
  }
}

fn maybe_set_body(request: Request(String), body: Option(String)) {
  case body {
    Some(b) -> request.set_body(request, b)
    None -> request
  }
}

fn maybe_apply_headers(
  request: Request(String),
  headers: Option(List(#(String, String))),
) {
  case headers {
    Some(h) ->
      list.fold(h, request, fn(r, header) {
        request.set_header(r, header.0, header.1)
      })
    None -> request
  }
}

fn maybe_set_port(request: Request(String), port: Option(Int)) {
  case port {
    Some(p) -> request.set_port(request, p)
    None -> request
  }
}

fn result_or_error(
  r: Result(Response(a), hackney.Error),
) -> Result(Response(a), DockerError) {
  case r {
    Error(hackney.Other(_)) -> Error(UnknownError("An unknown error occurred"))
    Error(hackney.InvalidUtf8Response) ->
      Error(UnknownError("Invalid UTF-8 Response"))
    Ok(response) -> Ok(response)
  }
}

@external(erlang, "gleam_hackney_ffi", "send")
fn ffi_send(
  a: Method,
  b: String,
  c: List(http.Header),
  d: BytesTree,
) -> Result(Response(BitArray), hackney.Error)

pub fn socket_send_bits(
  req: Request(BytesTree),
  socket_path: String,
) -> Result(Response(BitArray), hackney.Error) {
  let path = "http+unix://" <> uri.percent_encode(socket_path) <> req.path

  ffi_send(req.method, path, req.headers, req.body)
  |> result.map(fn(res) {
    Response(..res, headers: list.map(res.headers, normalise_header))
  })
}

fn normalise_header(header: http.Header) -> http.Header {
  #(string.lowercase(header.0), header.1)
}

pub fn socket_send(
  req: Request(String),
  socket_path: String,
) -> Result(Response(String), hackney.Error) {
  let req =
    req
    |> request.map(bytes_tree.from_string)

  use resp <- result.try(socket_send_bits(req, socket_path))

  case bit_array.to_string(resp.body) {
    Ok(body) -> Ok(response.set_body(resp, body))
    Error(_) -> Error(InvalidUtf8Response)
  }
}

pub fn humanize_error(error: DockerError) -> String {
  case error {
    InvalidUrl(url) -> "Invalid URL: " <> url
    Http(hackney.InvalidUtf8Response) -> "Invalid UTF-8 response from server"
    Http(hackney.Other(_)) -> "An unknown HTTP error occurred"
    UnexpectedStatus(status, body) ->
      "Unexpected status code: "
      <> int.to_string(status)
      <> " with body: "
      <> body
    DecodeError(decode_error) ->
      "Failed to decode response: " <> string.inspect(decode_error)
    SocketNotFound(path) -> "Docker socket not found at path: " <> path
    UnknownError(message) -> "Unknown error: " <> message
  }
}
