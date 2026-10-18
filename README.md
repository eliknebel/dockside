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
