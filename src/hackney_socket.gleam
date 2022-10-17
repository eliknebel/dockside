// FORKED FROM gleam/hackney to support http+unix sockets
import gleam/dynamic.{Dynamic}
import gleam/http.{Method}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/bit_string
import gleam/bit_builder.{BitBuilder}
import gleam/string
import gleam/list

pub type Error {
  InvalidUtf8Response
  // TODO: refine error type
  Other(Dynamic)
}

external fn ffi_send(
  Method,
  String,
  List(http.Header),
  BitBuilder,
) -> Result(Response(BitString), Error) =
  "gleam_hackney_ffi" "send"

external fn urlencode(String) -> String =
  "hackney_url" "urlencode"

pub fn send_socket_bits(
  request: Request(BitBuilder),
  socket_path: String,
) -> Result(Response(BitString), Error) {
  try response =
    ["http+unix://", urlencode(socket_path), request.path]
    |> string.join("")
    |> ffi_send(request.method, _, request.headers, request.body)
  let headers = list.map(response.headers, normalise_header)
  Ok(Response(..response, headers: headers))
}

pub fn send_socket(
  req: Request(String),
  socket_path: String,
) -> Result(Response(String), Error) {
  try resp =
    req
    |> request.map(bit_builder.from_string)
    |> send_socket_bits(socket_path)

  case bit_string.to_string(resp.body) {
    Ok(body) -> Ok(response.set_body(resp, body))
    Error(_) -> Error(InvalidUtf8Response)
  }
}

fn normalise_header(header: http.Header) -> http.Header {
  #(string.lowercase(header.0), header.1)
}
