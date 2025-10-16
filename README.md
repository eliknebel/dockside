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

Each module wraps the documented REST endpoint (see `/docs/plan.md`) and returns either decoded data or raw JSON/text so callers can compose their own workflows. All functions accept a `docker.DockerClient`, which can target a remote host or the local Unix socket.

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add dockside
```

and its documentation can be found at <https://hexdocs.pm/dockside>.
