import docker
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

pub fn path_with_query(path: String, query: List(#(String, String))) -> String {
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

pub fn expect_body(
  result: Result(response.Response(String), docker.DockerError),
) -> Result(String, String) {
  result
  |> docker.map_error
  |> result.map(fn(res) { res.body })
}

pub fn expect_nil(
  result: Result(response.Response(String), docker.DockerError),
) -> Result(Nil, String) {
  result
  |> docker.map_error
  |> result.map(fn(_) { Nil })
}

pub fn append_optional(
  query: List(#(String, String)),
  key: String,
  value: Option(String),
) -> List(#(String, String)) {
  case value {
    Some(v) -> list.append(query, [#(key, v)])
    None -> query
  }
}

pub fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

pub fn append_bool(
  query: List(#(String, String)),
  key: String,
  value: Bool,
) -> List(#(String, String)) {
  list.append(query, [#(key, bool_to_string(value))])
}

pub fn int_option_to_string(value: Option(Int)) -> Option(String) {
  case value {
    Some(v) -> Some(int.to_string(v))
    None -> None
  }
}

pub fn optional_headers(
  headers: List(#(String, String)),
) -> Option(List(#(String, String))) {
  case headers {
    [] -> None
    _ -> Some(headers)
  }
}
