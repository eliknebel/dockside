import dockside/k8s
import dockside/k8s/options
import dockside/k8s/paths
import dockside/k8s/request_helpers
import gleam/http.{Delete, Get, Post, Put}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

const core_v1 = paths.Core("v1")

pub type PodLogOptions {
  PodLogOptions(
    container: Option(String),
    follow: Bool,
    previous: Bool,
    timestamps: Bool,
    tail_lines: Option(Int),
    since_seconds: Option(Int),
    limit_bytes: Option(Int),
  )
}

pub fn default_pod_log_options() -> PodLogOptions {
  PodLogOptions(
    container: None,
    follow: False,
    previous: False,
    timestamps: False,
    tail_lines: None,
    since_seconds: None,
    limit_bytes: None,
  )
}

pub fn list_pods(
  client: k8s.K8sClient,
  namespace: Option(String),
  opts: options.ListOptions,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(client, namespace, "pods"))

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_pod(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "pods",
    name,
  ))

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn create_pod(
  client: k8s.K8sClient,
  namespace: Option(String),
  pod: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(client, namespace, "pods"))

  k8s.send_json_request(client, Post, path, [], pod)
  |> request_helpers.expect_body
}

pub fn replace_pod(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
  pod: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "pods",
    name,
  ))

  k8s.send_json_request(client, Put, path, [], pod)
  |> request_helpers.expect_body
}

pub fn delete_pod(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "pods",
    name,
  ))

  k8s.send_request(client, Delete, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn pod_logs(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
  opts: PodLogOptions,
) -> Result(String, String) {
  use ns <- result.try(request_helpers.resolve_namespace(client, namespace))
  let path = paths.subresource_path(core_v1, Some(ns), "pods", name, "log")

  k8s.send_request(client, Get, path, pod_log_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn list_services(
  client: k8s.K8sClient,
  namespace: Option(String),
  opts: options.ListOptions,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "services",
  ))

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_service(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "services",
    name,
  ))

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn create_service(
  client: k8s.K8sClient,
  namespace: Option(String),
  service: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "services",
  ))

  k8s.send_json_request(client, Post, path, [], service)
  |> request_helpers.expect_body
}

pub fn replace_service(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
  service: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "services",
    name,
  ))

  k8s.send_json_request(client, Put, path, [], service)
  |> request_helpers.expect_body
}

pub fn delete_service(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "services",
    name,
  ))

  k8s.send_request(client, Delete, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn list_config_maps(
  client: k8s.K8sClient,
  namespace: Option(String),
  opts: options.ListOptions,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "configmaps",
  ))

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_config_map(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "configmaps",
    name,
  ))

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn create_config_map(
  client: k8s.K8sClient,
  namespace: Option(String),
  config_map: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "configmaps",
  ))

  k8s.send_json_request(client, Post, path, [], config_map)
  |> request_helpers.expect_body
}

pub fn replace_config_map(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
  config_map: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "configmaps",
    name,
  ))

  k8s.send_json_request(client, Put, path, [], config_map)
  |> request_helpers.expect_body
}

pub fn delete_config_map(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "configmaps",
    name,
  ))

  k8s.send_request(client, Delete, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn list_secrets(
  client: k8s.K8sClient,
  namespace: Option(String),
  opts: options.ListOptions,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "secrets",
  ))

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_secret(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "secrets",
    name,
  ))

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn create_secret(
  client: k8s.K8sClient,
  namespace: Option(String),
  secret: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "secrets",
  ))

  k8s.send_json_request(client, Post, path, [], secret)
  |> request_helpers.expect_body
}

pub fn replace_secret(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
  secret: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "secrets",
    name,
  ))

  k8s.send_json_request(client, Put, path, [], secret)
  |> request_helpers.expect_body
}

pub fn delete_secret(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "secrets",
    name,
  ))

  k8s.send_request(client, Delete, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn list_namespaces(
  client: k8s.K8sClient,
  opts: options.ListOptions,
) -> Result(String, String) {
  let path = paths.collection_path(core_v1, "namespaces")

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_namespace(
  client: k8s.K8sClient,
  name: String,
) -> Result(String, String) {
  let path = paths.resource_path(core_v1, None, "namespaces", name)

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn create_namespace(
  client: k8s.K8sClient,
  namespace: json.Json,
) -> Result(String, String) {
  let path = paths.collection_path(core_v1, "namespaces")

  k8s.send_json_request(client, Post, path, [], namespace)
  |> request_helpers.expect_body
}

pub fn replace_namespace(
  client: k8s.K8sClient,
  name: String,
  namespace: json.Json,
) -> Result(String, String) {
  let path = paths.resource_path(core_v1, None, "namespaces", name)

  k8s.send_json_request(client, Put, path, [], namespace)
  |> request_helpers.expect_body
}

pub fn delete_namespace(
  client: k8s.K8sClient,
  name: String,
) -> Result(String, String) {
  let path = paths.resource_path(core_v1, None, "namespaces", name)

  k8s.send_request(client, Delete, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn list_nodes(
  client: k8s.K8sClient,
  opts: options.ListOptions,
) -> Result(String, String) {
  let path = paths.collection_path(core_v1, "nodes")

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_node(client: k8s.K8sClient, name: String) -> Result(String, String) {
  let path = paths.resource_path(core_v1, None, "nodes", name)

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

fn namespaced_collection_path(
  client: k8s.K8sClient,
  namespace: Option(String),
  resource: String,
) -> Result(String, String) {
  use ns <- result.try(request_helpers.resolve_namespace(client, namespace))
  Ok(paths.namespaced_collection_path(core_v1, ns, resource))
}

fn namespaced_resource_path(
  client: k8s.K8sClient,
  namespace: Option(String),
  resource: String,
  name: String,
) -> Result(String, String) {
  use ns <- result.try(request_helpers.resolve_namespace(client, namespace))
  Ok(paths.resource_path(core_v1, Some(ns), resource, name))
}

fn pod_log_query(opts: PodLogOptions) -> List(#(String, String)) {
  let PodLogOptions(
    container: container,
    follow: follow,
    previous: previous,
    timestamps: timestamps,
    tail_lines: tail_lines,
    since_seconds: since_seconds,
    limit_bytes: limit_bytes,
  ) = opts

  []
  |> append_optional("container", container)
  |> append_optional_int("tailLines", tail_lines)
  |> append_optional_int("sinceSeconds", since_seconds)
  |> append_optional_int("limitBytes", limit_bytes)
  |> append_flag("follow", follow)
  |> append_flag("previous", previous)
  |> append_flag("timestamps", timestamps)
}

fn append_optional(
  query: List(#(String, String)),
  key: String,
  value: Option(String),
) -> List(#(String, String)) {
  case value {
    Some(v) -> list.append(query, [#(key, v)])
    None -> query
  }
}

fn append_optional_int(
  query: List(#(String, String)),
  key: String,
  value: Option(Int),
) -> List(#(String, String)) {
  case value {
    Some(v) -> list.append(query, [#(key, int.to_string(v))])
    None -> query
  }
}

fn append_flag(
  query: List(#(String, String)),
  key: String,
  value: Bool,
) -> List(#(String, String)) {
  case value {
    True -> list.append(query, [#(key, "true")])
    False -> query
  }
}
