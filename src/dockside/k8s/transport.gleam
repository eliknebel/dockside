/// Opt-in HTTP transport settings. Existing `from_url` clients retain their
/// original transport. Configured requests own their connections (no pooling).
import gleam/bit_array
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import gleam/string
import gleam/uri

pub type Options {
  Options(
    ca_file: Option(String),
    verify_peer: Bool,
    connect_timeout_ms: Int,
    read_timeout_ms: Int,
    request_timeout_ms: Int,
    follow_redirects: Bool,
  )
}

/// Errors deliberately contain neither credentials nor response bodies.
pub type Error {
  InvalidOptions
  Timeout
  Tls
  Unavailable
  InvalidUtf8
}

pub fn defaults() -> Options {
  Options(None, True, 10_000, 10_000, 10_000, False)
}

pub fn send(
  req: Request(String),
  options: Options,
) -> Result(Response(String), Error) {
  use response <- result.try(send_bits(
    req.method,
    req |> request.to_uri |> uri.to_string,
    req.headers,
    req.body,
    options,
  ))
  use body <- result.try(
    bit_array.to_string(response.body)
    |> result.map_error(fn(_) { InvalidUtf8 }),
  )
  Ok(
    response.Response(
      ..response,
      headers: list.map(response.headers, fn(header) {
        #(string.lowercase(header.0), header.1)
      }),
      body: body,
    ),
  )
}

@external(erlang, "dockside_k8s_transport", "send")
fn send_bits(
  method: http.Method,
  url: String,
  headers: List(#(String, String)),
  body: String,
  options: Options,
) -> Result(Response(BitArray), Error)
