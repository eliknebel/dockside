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
    K8sHttp(default_namespace: namespace, ..) -> namespace
    K8sMock(default_namespace: namespace, ..) -> namespace
  }
}

pub fn add_header(client: K8sClient, key: String, value: String) -> K8sClient {
  let normalised = string.lowercase(key)

  case client {
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
  case client {
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
      |> hackney.send()
      |> result_or_error()
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
