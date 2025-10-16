## Dockside Engine API v1.51 Expansion Plan

### 1. Objectives
- Upgrade the existing core to target the Docker Engine API v1.51 over HTTP and Unix sockets.
- Provide idiomatic Gleam modules covering the remaining top-level API groups (containers, images, system, networks, volumes, exec, swarm, services, nodes, tasks, secrets, configs, plugins, distribution, events, build, auth).
- Balance typed responses with practicality: supply structured decoders for stable, frequently used endpoints and expose raw JSON for highly dynamic shapes.
- Maintain consistent error handling (`DockerError`) and request building ergonomics across the library.

### 2. Architecture & Cross-Cutting Concerns
- **Core client (`docker.gleam`)**
  - Handles protocol (HTTP/socket) selection, header application, JSON body encoding, query-string encoding, and status-code validation.
  - Exposes helpers (`request_json`, `request_stream`, `build_path`, etc.) consumed by higher-level modules.
- **Type/Decoder strategy**
  - Share common types in resource modules; prefer Gleam records for deterministic schemas (list/info/update operations).
  - For polymorphic payloads (e.g. `docker system events`, `distribution` endpoints) return `json.Json`.
- **Tests**
  - Use `DockerMock` to exercise happy-path behaviour and error surfacing for each module.
  - Key coverage: at least one test per module per HTTP verb family (GET/POST/DELETE) ensuring request paths and decoding.

### 3. Module Rollout
1. **Core Enhancements**
   - Query builder, JSON body helper, `ensure_success`, response streaming abstraction.
   - Update documentation/README with API coverage table.
2. **Existing Resource Enhancements**
   - `containers`: add create/inspect/start/stop/restart/kill/wait/logs/stats/remove/prune/commit/copy/archive/resize/attach.
   - `images`: add build/create/pull/push/tag/remove/inspect/history/search/prune.
3. **New Resource Modules**
   - `system`: ping/version/info/events/df/data-usage.
   - `networks`: list/create/inspect/connect/disconnect/remove/prune.
   - `volumes`: list/create/inspect/remove/prune.
   - `exec`: create/start/resize/inspect.
   - `swarm`: inspect/init/join/leave/update/unlock/key/rotate.
   - `services`: list/create/inspect/update/remove/logs.
   - `tasks`: list/inspect.
   - `nodes`: list/inspect/update/remove.
   - `secrets`, `configs`, `plugins`, `distribution`, `auth`, `builder`, `session`.
4. **Advanced/Streaming Helpers**
   - Provide specialised functions for websocket/stream endpoints where applicable (follow logs/stats).
   - Document caveats for endpoints requiring tar streams or chunked encodings; expose low-level request helpers.

### 4. Documentation & Examples
- Update `README.md` with usage examples for primary modules.
- Add module-level doc comments describing supported endpoints, request options and response types.
- Provide guidance on enabling Unix socket usage and authentication headers (bearer/basic).

### 5. Delivery Checklist
- ✅ Core upgraded to v1.51
- ✅ Plan documented (this file)
- ✅ Modules implemented according to rollout
- ✅ Tests updated/added and passing (`gleam test`)
- ✅ README + module docs refreshed
