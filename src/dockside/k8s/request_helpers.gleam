import dockside/k8s
import dockside/utils
import gleam/dynamic/decode
import gleam/http/response
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result

pub fn expect_body(
  result: Result(response.Response(String), k8s.K8sError),
) -> Result(String, String) {
  result
  |> k8s.map_error
  |> result.map(fn(res) { res.body })
}

pub fn expect_json(
  result: Result(response.Response(String), k8s.K8sError),
  decoder: decode.Decoder(t),
) -> Result(t, String) {
  use body <- result.try(expect_body(result))

  json.parse(body, decoder)
  |> result.map_error(fn(error) { utils.prettify_json_decode_error(error) })
}

pub fn expect_nil(
  result: Result(response.Response(String), k8s.K8sError),
) -> Result(Nil, String) {
  result
  |> k8s.map_error
  |> result.map(fn(_) { Nil })
}

pub fn resolve_namespace(
  client: k8s.K8sClient,
  namespace: Option(String),
) -> Result(String, String) {
  case namespace {
    Some(value) -> Ok(value)
    None ->
      case k8s.default_namespace(client) {
        Some(value) -> Ok(value)
        None ->
          Error(
            "Namespace required. Pass one explicitly or configure a default on the client.",
          )
      }
  }
}
