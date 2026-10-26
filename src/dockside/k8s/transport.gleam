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
  Cancelled
  Timeout
  Tls
  Unavailable
  InvalidUtf8
}

pub fn defaults() -> Options {
  Options(None, True, 10_000, 10_000, 10_000, False)
}

/// Opaque single-use request lifetime. Prepared handles own no connection.
pub type RequestHandle

/// Prepares an owned request without network I/O. Register its handle with the
/// lifecycle owner before await_response; owner death before execution is safe.
/// The creating process must call await_response. Any holder may cancel it.
pub fn prepare(
  req: Request(String),
  options: Options,
) -> Result(RequestHandle, Error) {
  prepare_bits(
    req.method,
    req |> request.to_uri |> uri.to_string,
    req.headers,
    req.body,
    options,
  )
}

/// Starts and waits for a prepared request in its creating process. Call once;
/// do not await a cancelled handle. Completion, timeout and cancellation release
/// the connection before returning. Cancellation returns Cancelled when awaiting.
pub fn await_response(handle: RequestHandle) -> Result(Response(String), Error) {
  use response <- result.try(await_bits(handle))
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

/// Cancels a prepared or active request and waits for connection-owner exit.
/// Safe to repeat and call from another process, including after creator death.
/// Do not launch replacement work if this returns Error (unexpected guardian death).
@external(erlang, "dockside_k8s_transport", "cancel")
pub fn cancel(handle: RequestHandle) -> Result(Nil, Error)

/// Sends an owned synchronous request with the configured TLS and timeout rules.
pub fn send(
  req: Request(String),
  options: Options,
) -> Result(Response(String), Error) {
  use handle <- result.try(prepare(req, options))
  await_response(handle)
}

@external(erlang, "dockside_k8s_transport", "prepare")
fn prepare_bits(
  method: http.Method,
  url: String,
  headers: List(#(String, String)),
  body: String,
  options: Options,
) -> Result(RequestHandle, Error)

@external(erlang, "dockside_k8s_transport", "await")
fn await_bits(handle: RequestHandle) -> Result(Response(BitArray), Error)

/// Opaque single-use HTTP follow lifetime. Preparation starts no connection.
pub type StreamHandle

/// One available body fragment (at most 65,536 bytes), or a clean response end.
pub type StreamChunk {
  Chunk(BitArray)
  End
}

/// Prepares an owned pull stream without network I/O. Only the creating process
/// can start/read it; any holder may cancel. Streams require verified TLS and
/// disabled redirects. The request timeout bounds startup/headers only.
pub fn prepare_stream(
  req: Request(String),
  options: Options,
) -> Result(StreamHandle, Error) {
  prepare_stream_bits(
    req.method,
    req |> request.to_uri |> uri.to_string,
    req.headers,
    req.body,
    options,
  )
}

/// Starts once in the creating process and returns headers before body completion.
/// Healthy body reads have no idle deadline. Register the handle before starting.
pub fn start_stream(handle: StreamHandle) -> Result(Response(Nil), Error) {
  use head <- result.try(start_stream_bits(handle))
  Ok(
    response.Response(
      ..head,
      headers: list.map(head.headers, fn(header) {
        #(string.lowercase(header.0), header.1)
      }),
    ),
  )
}

@external(erlang, "dockside_k8s_stream", "start")
fn start_stream_bits(handle: StreamHandle) -> Result(Response(Nil), Error)

/// Reads one available fragment in the creating process. Does not wait to fill
/// a batch or an advertised HTTP chunk. Cancel from another holder to interrupt.
@external(erlang, "dockside_k8s_stream", "next")
pub fn next_chunk(handle: StreamHandle) -> Result(StreamChunk, Error)

/// Cancels even a blocked header/body read and waits for connection-owner exit.
/// Repeatable; a failed cleanup receipt must prevent replacement work.
@external(erlang, "dockside_k8s_stream", "cancel")
pub fn cancel_stream(handle: StreamHandle) -> Result(Nil, Error)

@external(erlang, "dockside_k8s_stream", "prepare")
fn prepare_stream_bits(
  method: http.Method,
  url: String,
  headers: List(#(String, String)),
  body: String,
  options: Options,
) -> Result(StreamHandle, Error)
