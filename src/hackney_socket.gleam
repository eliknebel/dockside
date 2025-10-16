// FORKED FROM https://github.com/gleam-lang/hackney to support http+unix sockets
import gleam/bit_array
import gleam/bytes_tree
import gleam/hackney.{type Error, InvalidUtf8Response}
import gleam/http
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/list
import gleam/string

@external(erlang, "gleam_hackney_ffi", "send")
fn ffi_send(
  method: http.Method,
  url: String,
  headers: List(http.Header),
  body: bytes_tree.BytesTree,
) -> Result(http_response.Response(BitArray), Error)

@external(erlang, "hackney_url", "urlencode")
fn urlencode(value: String) -> String

pub fn send_socket_bits(
  request: http_request.Request(bytes_tree.BytesTree),
  socket_path: String,
) -> Result(http_response.Response(BitArray), Error) {
  case
    ["http+unix://", urlencode(socket_path), request.path]
    |> string.join("")
    |> ffi_send(request.method, _, request.headers, request.body)
  {
    Ok(response) -> {
      let headers = list.map(response.headers, normalise_header)
      Ok(http_response.Response(..response, headers: headers))
    }
    Error(error) -> Error(error)
  }
}

pub fn send_socket(
  req: http_request.Request(String),
  socket_path: String,
) -> Result(http_response.Response(String), Error) {
  case
    req
    |> http_request.map(bytes_tree.from_string)
    |> send_socket_bits(socket_path)
  {
    Ok(resp) ->
      case bit_array.to_string(resp.body) {
        Ok(body) -> Ok(http_response.set_body(resp, body))
        Error(_) -> Error(InvalidUtf8Response)
      }
    Error(error) -> Error(error)
  }
}

fn normalise_header(header: http.Header) -> http.Header {
  #(string.lowercase(header.0), header.1)
}
