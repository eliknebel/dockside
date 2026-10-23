/// Run with `node test/scripts/transport.mjs` (Node 20+ and OpenSSL required).
import dockside/k8s
import dockside/k8s/transport
import envoy
import gleam/http
import gleam/http/response
import gleam/option.{None, Some}
import gleeunit/should

pub fn main() {
  let assert Ok(url) = envoy.get("TLS_URL")
  let assert Ok(handshake_url) = envoy.get("TLS_HANDSHAKE_URL")
  let assert Ok(ca) = envoy.get("TLS_CA")
  let assert Ok(wrong_url) = envoy.get("TLS_WRONG_URL")
  let assert Ok(wrong_ca) = envoy.get("TLS_WRONG_CA")
  let options = transport.Options(..transport.defaults(), ca_file: Some(ca))
  let client = make_client(url, options)
  let assert Ok(response) = get(client, "/ok")
  response.body |> should.equal("ok")
  get(make_client(url, transport.defaults()), "/ok")
  |> should.equal(Error(k8s.Transport(transport.Tls)))
  get(
    make_client(
      wrong_url,
      transport.Options(..options, ca_file: Some(wrong_ca)),
    ),
    "/ok",
  )
  |> should.equal(Error(k8s.Transport(transport.Tls)))
  get(client, "/redirect") |> should.equal(Error(k8s.UnexpectedStatus(302, "")))
  let bounded =
    make_client(url, transport.Options(..options, request_timeout_ms: 250))
  timed_timeout(fn() { get(bounded, "/stall") }) |> should.be_true
  timed_timeout(fn() { get(bounded, "/trickle") }) |> should.be_true
  cancel(fn() { get(client, "/stall") })
  let assert Ok(active) = get(client, "/active")
  active.body |> should.equal("1")
  get(
    make_client(url, transport.Options(..options, request_timeout_ms: 0)),
    "/ok",
  )
  |> should.equal(Error(k8s.Transport(transport.InvalidOptions)))
  // Preparation itself must send no request, and cancellation is repeatable.
  let assert Ok(unstarted) =
    k8s.prepare_request(client, http.Get, "/never-start", [], [], None)
  k8s.cancel_request(unstarted) |> should.equal(Ok(Nil))
  k8s.cancel_request(unstarted) |> should.equal(Ok(Nil))
  // Cancellation acknowledges the transport owner, not merely its caller.
  cancel_waits_for_owner(
    fn() {
      k8s.prepare_request(client, http.Get, "/cancel-stall", [], [], None)
    },
    k8s.await_request,
    k8s.cancel_request,
    fn() { get(client, "/wait-cancel-stall") },
    fn() { get(client, "/replacement") },
  )
  |> should.be_true
  cancel_active(
    fn() {
      k8s.prepare_request(client, http.Get, "/cancel-stall", [], [], None)
    },
    k8s.await_request,
    k8s.cancel_request,
    fn() { get(client, "/wait-cancel-stall") },
  )
  |> should.be_true
  guardian_failure(
    fn() {
      k8s.prepare_request(client, http.Get, "/failure-stall", [], [], None)
    },
    k8s.await_request,
    k8s.cancel_request,
    fn() { get(client, "/wait-failure-stall") },
  )
  |> should.be_true
  let assert Ok(completed) =
    k8s.prepare_request(client, http.Get, "/ok", [], [], None)
  let assert Ok(response) = k8s.await_request(completed)
  response.body |> should.equal("ok")
  k8s.cancel_request(completed) |> should.equal(Ok(Nil))
  // Replacing a CA at the same path must not reuse OTP's cached PEM contents.
  let original = read_file(ca)
  write_file(ca, read_file(wrong_ca))
  get(client, "/ok") |> should.equal(Error(k8s.Transport(transport.Tls)))
  write_file(ca, original)
  get(client, "/ok") |> should.be_ok
  let read_bounded =
    make_client(
      url,
      transport.Options(
        ..options,
        read_timeout_ms: 80,
        request_timeout_ms: 1000,
      ),
    )
  get(read_bounded, "/stall")
  |> should.equal(Error(k8s.Transport(transport.Timeout)))
  let connect_bounded =
    make_client(
      handshake_url,
      transport.Options(
        ..options,
        connect_timeout_ms: 80,
        request_timeout_ms: 250,
      ),
    )
  timed_timeout(fn() { get(connect_bounded, "/ok") }) |> should.be_true
  // Wrapping preserves namespace/header helpers, and replacing options works.
  client
  |> k8s.with_default_namespace("test")
  |> k8s.default_namespace
  |> should.equal(Some("test"))
  client
  |> k8s.with_default_namespace("test")
  |> k8s.clear_default_namespace
  |> k8s.default_namespace
  |> should.equal(None)
}

fn make_client(url: String, options: transport.Options) -> k8s.K8sClient {
  let assert Ok(client) = k8s.from_url(url)
  client
  |> k8s.with_http_options(options)
  |> k8s.with_bearer_token("sentinel-private-token")
}

fn get(client: k8s.K8sClient, path: String) {
  k8s.send_request(client, http.Get, path, [], [], None)
}

@external(erlang, "transport_test_helpers", "timed_timeout")
fn timed_timeout(request: fn() -> a) -> Bool

@external(erlang, "transport_test_helpers", "cancel")
fn cancel(request: fn() -> a) -> Nil

@external(erlang, "transport_test_helpers", "read_file")
fn read_file(path: String) -> String

@external(erlang, "transport_test_helpers", "write_file")
fn write_file(path: String, contents: String) -> Nil

@external(erlang, "transport_test_helpers", "cancel_waits_for_owner")
fn cancel_waits_for_owner(
  prepare: fn() -> Result(k8s.PendingRequest, k8s.K8sError),
  await_response: fn(k8s.PendingRequest) ->
    Result(response.Response(String), k8s.K8sError),
  cancel: fn(k8s.PendingRequest) -> Result(Nil, k8s.K8sError),
  ready: fn() -> Result(response.Response(String), k8s.K8sError),
  replacement: fn() -> Result(response.Response(String), k8s.K8sError),
) -> Bool

@external(erlang, "transport_test_helpers", "cancel_active")
fn cancel_active(
  prepare: fn() -> Result(k8s.PendingRequest, k8s.K8sError),
  await_response: fn(k8s.PendingRequest) ->
    Result(response.Response(String), k8s.K8sError),
  cancel: fn(k8s.PendingRequest) -> Result(Nil, k8s.K8sError),
  ready: fn() -> Result(response.Response(String), k8s.K8sError),
) -> Bool

@external(erlang, "transport_test_helpers", "guardian_failure")
fn guardian_failure(
  prepare: fn() -> Result(k8s.PendingRequest, k8s.K8sError),
  await_response: fn(k8s.PendingRequest) ->
    Result(response.Response(String), k8s.K8sError),
  cancel: fn(k8s.PendingRequest) -> Result(Nil, k8s.K8sError),
  ready: fn() -> Result(response.Response(String), k8s.K8sError),
) -> Bool
