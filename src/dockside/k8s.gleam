import dockside/k8s/transport
import gleam/http.{type Method, type Scheme, scheme_from_string}
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

import gleam/hackney
import gleam/json

pub type K8sClient {
  /// Opt-in wrapper preserves the existing HTTP and mock constructors.
  K8sConfigured(client: K8sClient, options: transport.Options)
  K8sHttp(
    scheme: Scheme,
    host: String,
    port: Option(Int),
    base_path: String,
    default_namespace: Option(String),
    default_headers: List(#(String, String)),
  )
  K8sMock(
    base_path: String,
    default_namespace: Option(String),
    default_headers: List(#(String, String)),
    mock_fn: MockFn,
  )
}

pub type K8sError {
  Transport(transport.Error)
  InvalidUrl(String)
  Http(hackney.Error)
  UnexpectedStatus(Int, String)
  DecodeError(json.DecodeError)
  UnknownError(String)
}

type MockFn =
  fn(
    Method,
    String,
    List(#(String, String)),
    Option(String),
    List(#(String, String)),
  ) ->
    Result(Response(String), K8sError)

pub fn from_url(base_url: String) -> Result(K8sClient, K8sError) {
  use #(scheme, host, port, base_path) <- result.try(parse_base_url(base_url))

  Ok(K8sHttp(
    scheme: scheme,
    host: host,
    port: port,
    base_path: base_path,
    default_namespace: None,
    default_headers: default_headers(),
  ))
}

/// Configure one client without changing defaults for other consumers.
pub fn with_http_options(
  client: K8sClient,
  options: transport.Options,
) -> K8sClient {
  case client {
    K8sConfigured(inner, _) -> K8sConfigured(inner, options)
    _ -> K8sConfigured(client, options)
  }
}

pub fn mock(mock_fn: MockFn) -> K8sClient {
  K8sMock(
    base_path: "",
    default_namespace: None,
    default_headers: default_headers(),
    mock_fn: mock_fn,
  )
}

pub fn with_default_namespace(client: K8sClient, namespace: String) -> K8sClient {
  set_namespace(client, Some(namespace))
}

pub fn clear_default_namespace(client: K8sClient) -> K8sClient {
  set_namespace(client, None)
}

pub fn default_namespace(client: K8sClient) -> Option(String) {
  case client {
    K8sConfigured(inner, _) -> default_namespace(inner)
    K8sHttp(default_namespace: namespace, ..) -> namespace
    K8sMock(default_namespace: namespace, ..) -> namespace
  }
}

pub fn add_header(client: K8sClient, key: String, value: String) -> K8sClient {
  let normalised = string.lowercase(key)

  case client {
    K8sConfigured(inner, options) ->
      K8sConfigured(add_header(inner, key, value), options)
    K8sHttp(
      scheme: scheme,
      host: host,
      port: port,
      base_path: base_path,
      default_namespace: namespace,
      default_headers: headers,
    ) ->
      K8sHttp(
        scheme: scheme,
        host: host,
        port: port,
        base_path: base_path,
        default_namespace: namespace,
        default_headers: list.key_set(headers, normalised, value),
      )

    K8sMock(
      base_path: base_path,
      default_namespace: namespace,
      default_headers: headers,
      mock_fn: mock_fn,
    ) ->
      K8sMock(
        base_path: base_path,
        default_namespace: namespace,
        default_headers: list.key_set(headers, normalised, value),
        mock_fn: mock_fn,
      )
  }
}

pub fn with_bearer_token(client: K8sClient, token: String) -> K8sClient {
  add_header(client, "authorization", "Bearer " <> token)
}

pub fn map_error(result: Result(a, K8sError)) -> Result(a, String) {
  case result {
    Ok(value) -> Ok(value)
    Error(error) -> Error(humanize_error(error))
  }
}

pub fn send_request(
  client: K8sClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  headers: List(#(String, String)),
  body: Option(String),
) -> Result(Response(String), K8sError) {
  send_with(client, method, path, query, headers, body, None)
}

/// A prepared single-use request. No upstream connection exists before await.
pub opaque type PendingRequest {
  HttpRequest(transport.RequestHandle)
  MockRequest(fn() -> Result(Response(String), K8sError))
}

/// Prepares an owned cancellable request without I/O. Register the returned
/// handle before starting it with await_request in the creating process. Uses
/// configured options, or owned-transport defaults for an unconfigured client.
pub fn prepare_request(
  client: K8sClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  headers: List(#(String, String)),
  body: Option(String),
) -> Result(PendingRequest, K8sError) {
  prepare_with(client, method, path, query, headers, body, transport.defaults())
}

fn prepare_with(client, method, path, query, headers, body, options) {
  case client {
    K8sConfigured(inner, options) ->
      prepare_with(inner, method, path, query, headers, body, options)
    K8sHttp(
      scheme: scheme,
      host: host,
      port: port,
      base_path: base_path,
      default_headers: default_headers,
      ..,
    ) -> {
      request.new()
      |> request.set_method(method)
      |> request.set_scheme(scheme)
      |> request.set_host(host)
      |> maybe_set_port(port)
      |> request.set_path(build_path(base_path, path))
      |> maybe_set_query(query)
      |> apply_headers(combine_headers(default_headers, headers))
      |> maybe_set_body(body)
      |> transport.prepare(options)
      |> result.map(HttpRequest)
      |> result.map_error(Transport)
    }
    K8sMock(..) ->
      Ok(
        MockRequest(fn() {
          send_request(client, method, path, query, headers, body)
        }),
      )
  }
}

/// Executes a prepared request once, in its creating process, preserving status
/// and error mapping. Do not await a handle after cancelling it.
pub fn await_request(
  pending: PendingRequest,
) -> Result(Response(String), K8sError) {
  case pending {
    HttpRequest(handle) ->
      transport.await_response(handle)
      |> result.map_error(Transport)
      |> ensure_success_or_error
    MockRequest(run) -> run()
  }
}

/// Cancels and waits for connection-owner exit. Repeat calls are safe. A failure
/// means cleanup cannot be confirmed; do not start replacement work in that case.
/// Mock requests have no owned connection and must not be awaited after cancel.
pub fn cancel_request(pending: PendingRequest) -> Result(Nil, K8sError) {
  case pending {
    HttpRequest(handle) ->
      transport.cancel(handle) |> result.map_error(Transport)
    MockRequest(_) -> Ok(Nil)
  }
}

fn send_with(
  client: K8sClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  headers: List(#(String, String)),
  body: Option(String),
  http_options: Option(transport.Options),
) -> Result(Response(String), K8sError) {
  case client {
    K8sConfigured(inner, options) ->
      send_with(inner, method, path, query, headers, body, Some(options))
    K8sHttp(
      scheme: scheme,
      host: host,
      port: port,
      base_path: base_path,
      default_headers: default_headers,
      ..,
    ) -> {
      let full_path = build_path(base_path, path)
      let combined_headers = combine_headers(default_headers, headers)

      request.new()
      |> request.set_method(method)
      |> request.set_scheme(scheme)
      |> request.set_host(host)
      |> maybe_set_port(port)
      |> request.set_path(full_path)
      |> maybe_set_query(query)
      |> apply_headers(combined_headers)
      |> maybe_set_body(body)
      |> send_http(http_options)
      |> ensure_success_or_error()
    }

    K8sMock(
      base_path: base_path,
      default_headers: default_headers,
      mock_fn: mock_fn,
      ..,
    ) -> {
      let full_path = build_path(base_path, path)
      mock_fn(
        method,
        full_path,
        query,
        body,
        combine_headers(default_headers, headers),
      )
      |> ensure_success_or_error()
    }
  }
}

fn send_http(
  req: request.Request(String),
  options: Option(transport.Options),
) -> Result(Response(String), K8sError) {
  case options {
    None -> req |> hackney.send |> result_or_error
    Some(options) -> transport.send(req, options) |> result.map_error(Transport)
  }
}

pub fn send_json_request(
  client: K8sClient,
  method: Method,
  path: String,
  query: List(#(String, String)),
  payload: json.Json,
) -> Result(Response(String), K8sError) {
  let body = json.to_string(payload)
  send_request(
    client,
    method,
    path,
    query,
    [#("content-type", "application/json")],
    Some(body),
  )
}

pub fn humanize_error(error: K8sError) -> String {
  case error {
    Transport(_) -> "Configured Kubernetes HTTP transport failed"
    InvalidUrl(url) -> "Invalid Kubernetes API URL: " <> url
    Http(hackney.InvalidUtf8Response) ->
      "Invalid UTF-8 response from Kubernetes API"
    Http(hackney.Other(_)) -> "HTTP error while contacting Kubernetes API"
    UnexpectedStatus(status, body) ->
      "Unexpected status code: "
      <> int.to_string(status)
      <> " with body: "
      <> body
    DecodeError(decode_error) ->
      "Failed to decode Kubernetes response: " <> string.inspect(decode_error)
    UnknownError(message) -> "Unknown Kubernetes client error: " <> message
  }
}

fn set_namespace(client: K8sClient, namespace: Option(String)) -> K8sClient {
  case client {
    K8sConfigured(inner, options) ->
      K8sConfigured(set_namespace(inner, namespace), options)
    K8sHttp(
      scheme: scheme,
      host: host,
      port: port,
      base_path: base_path,
      default_headers: headers,
      ..,
    ) ->
      K8sHttp(
        scheme: scheme,
        host: host,
        port: port,
        base_path: base_path,
        default_namespace: namespace,
        default_headers: headers,
      )

    K8sMock(
      base_path: base_path,
      default_headers: headers,
      mock_fn: mock_fn,
      ..,
    ) ->
      K8sMock(
        base_path: base_path,
        default_namespace: namespace,
        default_headers: headers,
        mock_fn: mock_fn,
      )
  }
}

fn ensure_success_or_error(
  result: Result(Response(String), K8sError),
) -> Result(Response(String), K8sError) {
  case result {
    Ok(response) ->
      case response.status >= 200 && response.status < 300 {
        True -> Ok(response)
        False -> Error(UnexpectedStatus(response.status, response.body))
      }

    Error(error) -> Error(error)
  }
}

fn combine_headers(
  default_headers: List(#(String, String)),
  headers: List(#(String, String)),
) -> List(#(String, String)) {
  let initial =
    list.map(default_headers, fn(header) {
      #(string.lowercase(header.0), header.1)
    })

  list.fold(headers, initial, fn(acc, header) {
    list.key_set(acc, string.lowercase(header.0), header.1)
  })
}

fn apply_headers(
  req: request.Request(String),
  headers: List(#(String, String)),
) -> request.Request(String) {
  list.fold(headers, req, fn(r, header) {
    request.set_header(r, header.0, header.1)
  })
}

fn maybe_set_query(
  req: request.Request(String),
  query: List(#(String, String)),
) -> request.Request(String) {
  case query {
    [] -> req
    _ -> request.set_query(req, query)
  }
}

fn maybe_set_body(
  req: request.Request(String),
  body: Option(String),
) -> request.Request(String) {
  case body {
    Some(b) -> request.set_body(req, b)
    None -> req
  }
}

fn maybe_set_port(
  req: request.Request(String),
  port: Option(Int),
) -> request.Request(String) {
  case port {
    Some(p) -> request.set_port(req, p)
    None -> req
  }
}

fn result_or_error(
  result: Result(Response(String), hackney.Error),
) -> Result(Response(String), K8sError) {
  case result {
    Ok(response) -> Ok(response)
    Error(error) -> Error(Http(error))
  }
}

fn parse_base_url(
  base_url: String,
) -> Result(#(Scheme, String, Option(Int), String), K8sError) {
  case uri.parse(base_url) {
    Ok(uri.Uri(
      scheme: scheme_opt,
      userinfo: _,
      host: host_opt,
      port: port_opt,
      path: path,
      query: _,
      fragment: _,
    )) ->
      case host_opt {
        Some(host) -> {
          let scheme_string = case scheme_opt {
            Some(value) -> value
            None -> "https"
          }

          case scheme_from_string(scheme_string) {
            Ok(scheme) ->
              Ok(#(scheme, host, port_opt, normalise_base_path(path)))

            Error(_) ->
              Error(InvalidUrl("Unsupported scheme in URL: " <> scheme_string))
          }
        }

        None -> Error(InvalidUrl("Base URL is missing a host: " <> base_url))
      }

    Error(_) ->
      Error(InvalidUrl("Unable to parse Kubernetes base URL: " <> base_url))
  }
}

fn normalise_base_path(path: String) -> String {
  let trimmed = string.trim(path)

  case trimmed {
    "" -> ""
    "/" -> ""
    _ -> {
      let leading = case string.starts_with(trimmed, "/") {
        True -> trimmed
        False -> "/" <> trimmed
      }

      case string.ends_with(leading, "/") {
        True -> string.drop_end(leading, 1)
        False -> leading
      }
    }
  }
}

fn build_path(base_path: String, path: String) -> String {
  let relative = case string.starts_with(path, "/") {
    True -> path
    False -> "/" <> path
  }

  case base_path {
    "" -> relative
    _ -> base_path <> relative
  }
}

fn default_headers() -> List(#(String, String)) {
  [
    #("accept", "application/json"),
    #("user-agent", "dockside-k8s"),
  ]
}

/// An owned HTTP stream. Finite mock clients cannot provide incremental I/O;
/// callers testing streams should inject typed stream operations instead.
pub opaque type PendingStream {
  HttpStream(transport.StreamHandle)
}

/// Prepares a GET stream without I/O, using configured or safe default transport
/// options. Register the returned handle before starting it in this process.
/// Supply fresh credentials when constructing the client for each opening.
pub fn prepare_stream_request(
  client: K8sClient,
  path: String,
  query: List(#(String, String)),
) -> Result(PendingStream, K8sError) {
  prepare_stream_with(client, path, query, transport.defaults())
}

fn prepare_stream_with(client, path, query, options) {
  case client {
    K8sConfigured(inner, options) ->
      prepare_stream_with(inner, path, query, options)
    K8sHttp(
      scheme: scheme,
      host: host,
      port: port,
      base_path: base_path,
      default_headers: headers,
      ..,
    ) ->
      request.new()
      |> request.set_method(http.Get)
      |> request.set_scheme(scheme)
      |> request.set_host(host)
      |> maybe_set_port(port)
      |> request.set_path(build_path(base_path, path))
      |> maybe_set_query(query)
      |> apply_headers(headers)
      |> request.set_header("accept-encoding", "identity")
      |> transport.prepare_stream(options)
      |> result.map(HttpStream)
      |> result.map_error(Transport)
    K8sMock(..) -> Error(Transport(transport.InvalidOptions))
  }
}

/// Opens the prepared stream once in its creator. Non-success statuses close
/// the connection and return only their status, with an empty error body.
pub fn start_stream(pending: PendingStream) -> Result(Response(Nil), K8sError) {
  let HttpStream(handle) = pending
  use head <- result.try(
    transport.start_stream(handle) |> result.map_error(Transport),
  )
  case head.status >= 200 && head.status < 300 {
    True -> Ok(head)
    False -> {
      use _ <- result.try(cancel_stream(pending))
      Error(UnexpectedStatus(head.status, ""))
    }
  }
}

/// Reads one available bounded byte fragment, or clean EOF, in the creator.
/// There is one read in flight; another holder can interrupt it with cancellation.
pub fn next_chunk(
  pending: PendingStream,
) -> Result(transport.StreamChunk, K8sError) {
  let HttpStream(handle) = pending
  transport.next_chunk(handle) |> result.map_error(Transport)
}

/// Cancels and acknowledges connection-owner exit. Safe before start and after
/// EOF or earlier cancellation. Never replace work when this returns an error.
pub fn cancel_stream(pending: PendingStream) -> Result(Nil, K8sError) {
  let HttpStream(handle) = pending
  transport.cancel_stream(handle) |> result.map_error(Transport)
}
