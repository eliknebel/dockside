//// Controlled HTTP/TLS stream qualification, run by test/scripts/stream.mjs.

import dockside/k8s
import dockside/k8s/transport
import envoy
import gleam/option.{Some}

/// Runs the integration suite against test-owned local peers only.
pub fn main() {
  let assert Ok(http_url) = envoy.get("STREAM_HTTP_URL")
  let assert Ok(tls_url) = envoy.get("STREAM_TLS_URL")
  let assert Ok(raw_url) = envoy.get("STREAM_RAW_URL")
  let assert Ok(raw_tls_url) = envoy.get("STREAM_RAW_TLS_URL")
  let assert Ok(wrong_url) = envoy.get("STREAM_WRONG_URL")
  let assert Ok(handshake_url) = envoy.get("STREAM_HANDSHAKE_URL")
  let assert Ok(ca) = envoy.get("STREAM_CA")
  let assert Ok(wrong_ca) = envoy.get("STREAM_WRONG_CA")
  let options =
    transport.Options(
      ..transport.defaults(),
      ca_file: Some(ca),
      request_timeout_ms: 1000,
      read_timeout_ms: 50,
    )
  let assert Ok(http_client) = k8s.from_url(http_url)
  let assert Ok(tls_client) = k8s.from_url(tls_url)
  let assert Ok(raw_client) = k8s.from_url(raw_url)
  let assert Ok(raw_tls_client) = k8s.from_url(raw_tls_url)
  let assert Ok(handshake_client) = k8s.from_url(handshake_url)
  let assert Ok(wrong_client) = k8s.from_url(wrong_url)
  run(
    k8s.with_http_options(http_client, options),
    k8s.with_http_options(tls_client, options),
    k8s.with_http_options(raw_client, options),
    k8s.with_http_options(raw_tls_client, options),
    k8s.with_http_options(
      wrong_client,
      transport.Options(..options, ca_file: Some(wrong_ca)),
    ),
    tls_client,
    ca,
    wrong_ca,
    k8s.with_http_options(handshake_client, options),
  )
}

@external(erlang, "stream_test_helpers", "run")
fn run(
  http: k8s.K8sClient,
  tls: k8s.K8sClient,
  raw: k8s.K8sClient,
  raw_tls: k8s.K8sClient,
  wrong: k8s.K8sClient,
  untrusted: k8s.K8sClient,
  ca: String,
  wrong_ca: String,
  handshake: k8s.K8sClient,
) -> Nil
