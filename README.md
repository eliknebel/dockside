# dockside

[![Package Version](https://img.shields.io/hexpm/v/dockside)](https://hex.pm/packages/dockside)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/dockside/)

A Gleam project

## Quick start

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```

## Engine API Coverage

Dockside targets the Docker Engine API `v1.51`, exposing high-level helpers for the most frequently used resources:

- `containers`: list, lifecycle (create/start/stop/restart/kill/pause/unpause/remove), inspection/logs/stats, update/wait/prune.
- `images`: list (with options), inspect/history/search/create/push/pull/tag/remove/prune.
- `networks`, `volumes`, `exec`, `system`, `swarm`, `services`, `tasks`, `nodes`, `secrets`, `configs`, `plugins`, `distribution`, `auth`.

If you need to talk to an older Docker Engine, set the `DOCKER_API_VERSION` environment variable (for example `1.44` or `v1.44`) and Dockside will automatically use that version. Blank or `auto` values fall back to the default `v1.51` target.

Each module wraps the documented REST endpoint (see `/docs/plan.md`) and returns either decoded data or raw JSON/text so callers can compose their own workflows. All functions accept a `docker.DockerClient`, which can target a remote host or the local Unix socket.

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add dockside
```

and its documentation can be found at <https://hexdocs.pm/dockside>.

### Kubernetes HTTP transport options

Existing `k8s.from_url` clients keep their transport behavior. To configure one
client, wrap it with `k8s.with_http_options(client, transport.defaults())` from
`dockside/k8s/transport`. `Options` selects a PEM `ca_file` (or system roots),
peer and hostname verification, TCP connect/read timeouts, a whole-request timeout,
and redirect handling. Defaults verify TLS, refuse redirects, and use 10 seconds
for all three timeouts. Positive timeouts must fit in 32 unsigned bits.

Configured requests use dedicated connections. The whole-request deadline covers
DNS, connection, TLS (including a stalled handshake), headers, and body, including a body that continuously sends
bytes. Hackney’s connect timeout covers TCP setup; the whole-request deadline
bounds the TLS handshake. Deadline expiry or caller termination kills the connection owner; completed
requests release their connections. CA files are decoded on each request so
replacing a file at the same path updates trust. The `Transport` error variant
contains a fixed category, without request credentials or response bodies.
Existing status/decode errors retain their existing contracts.

Run `node test/scripts/transport.mjs` with Node 20+ and OpenSSL to exercise a local
HTTPS fixture. It checks trusted/untrusted CA chains, wrong hostnames, redirect
isolation, stalled and trickling deadlines, caller cancellation, socket cleanup,
and CA rotation. Temporary certificate keys and servers are removed on exit.

### Explicit Kubernetes request cancellation

`k8s.prepare_request` returns an opaque `PendingRequest` without starting network
I/O. The creating worker must register that handle with its lifecycle owner
before calling `k8s.await_request`. Await starts the request and preserves ordinary
response/status handling. The owner may call `k8s.cancel_request` from another
process; a successful result acknowledges connection-owner exit, even if the
creating worker died. Wait for that result before launching replacement work.
Caller termination alone is not a cleanup acknowledgment.

Handles are single-use: await once in the creating process; do not await a cancelled
handle. Cancellation is safe to repeat. An awaiting request returns
`Transport(Cancelled)` when cancellation interrupts it. A handle-owned completion marker records confirmed connection-owner exit.
Late or repeated cancellation checks this marker; an earlier guardian failure
without confirmed cleanup returns an error, even after its process has disappeared. Creating-process death
also releases a prepared handle that never started. Mock requests remain lazy and
have no owned connection. For the explicit API, unconfigured HTTP clients use the
owned transport's defaults; existing `send_request` behavior is unchanged.

The TLS fixture also verifies that preparation sends no request, repeated cancel
is safe, cancellation waits while guardian cleanup is deliberately paused, and an
immediately started replacement has no overlap with the cancelled connection.
