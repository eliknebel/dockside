import dockside/k8s
import dockside/k8s/options
import dockside/k8s/paths
import dockside/k8s/request_helpers
import gleam/http.{Delete, Get, Post, Put}
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result

const apps_v1 = paths.Named(group: "apps", version: "v1")

pub fn list_deployments(
  client: k8s.K8sClient,
  namespace: Option(String),
  opts: options.ListOptions,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "deployments",
  ))

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_deployment(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "deployments",
    name,
  ))

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn create_deployment(
  client: k8s.K8sClient,
  namespace: Option(String),
  deployment: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "deployments",
  ))

  k8s.send_json_request(client, Post, path, [], deployment)
  |> request_helpers.expect_body
}

pub fn replace_deployment(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
  deployment: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "deployments",
    name,
  ))

  k8s.send_json_request(client, Put, path, [], deployment)
  |> request_helpers.expect_body
}

pub fn delete_deployment(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "deployments",
    name,
  ))

  k8s.send_request(client, Delete, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn get_deployment_scale(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use ns <- result.try(request_helpers.resolve_namespace(client, namespace))
  let path =
    paths.subresource_path(apps_v1, Some(ns), "deployments", name, "scale")

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn replace_deployment_scale(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
  scale: json.Json,
) -> Result(String, String) {
  use ns <- result.try(request_helpers.resolve_namespace(client, namespace))
  let path =
    paths.subresource_path(apps_v1, Some(ns), "deployments", name, "scale")

  k8s.send_json_request(client, Put, path, [], scale)
  |> request_helpers.expect_body
}

pub fn list_stateful_sets(
  client: k8s.K8sClient,
  namespace: Option(String),
  opts: options.ListOptions,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "statefulsets",
  ))

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_stateful_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "statefulsets",
    name,
  ))

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn create_stateful_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  stateful_set: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "statefulsets",
  ))

  k8s.send_json_request(client, Post, path, [], stateful_set)
  |> request_helpers.expect_body
}

pub fn replace_stateful_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
  stateful_set: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "statefulsets",
    name,
  ))

  k8s.send_json_request(client, Put, path, [], stateful_set)
  |> request_helpers.expect_body
}

pub fn delete_stateful_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "statefulsets",
    name,
  ))

  k8s.send_request(client, Delete, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn list_daemon_sets(
  client: k8s.K8sClient,
  namespace: Option(String),
  opts: options.ListOptions,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "daemonsets",
  ))

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_daemon_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "daemonsets",
    name,
  ))

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn create_daemon_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  daemon_set: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "daemonsets",
  ))

  k8s.send_json_request(client, Post, path, [], daemon_set)
  |> request_helpers.expect_body
}

pub fn replace_daemon_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
  daemon_set: json.Json,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "daemonsets",
    name,
  ))

  k8s.send_json_request(client, Put, path, [], daemon_set)
  |> request_helpers.expect_body
}

pub fn delete_daemon_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "daemonsets",
    name,
  ))

  k8s.send_request(client, Delete, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn list_replica_sets(
  client: k8s.K8sClient,
  namespace: Option(String),
  opts: options.ListOptions,
) -> Result(String, String) {
  use path <- result.try(namespaced_collection_path(
    client,
    namespace,
    "replicasets",
  ))

  k8s.send_request(client, Get, path, options.to_query(opts), [], None)
  |> request_helpers.expect_body
}

pub fn get_replica_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "replicasets",
    name,
  ))

  k8s.send_request(client, Get, path, [], [], None)
  |> request_helpers.expect_body
}

pub fn delete_replica_set(
  client: k8s.K8sClient,
  namespace: Option(String),
  name: String,
) -> Result(String, String) {
  use path <- result.try(namespaced_resource_path(
    client,
    namespace,
    "replicasets",
    name,
  ))

  k8s.send_request(client, Delete, path, [], [], None)
  |> request_helpers.expect_body
}

fn namespaced_collection_path(
  client: k8s.K8sClient,
  namespace: Option(String),
  resource: String,
) -> Result(String, String) {
  use ns <- result.try(request_helpers.resolve_namespace(client, namespace))
  Ok(paths.namespaced_collection_path(apps_v1, ns, resource))
}

fn namespaced_resource_path(
  client: k8s.K8sClient,
  namespace: Option(String),
  resource: String,
  name: String,
) -> Result(String, String) {
  use ns <- result.try(request_helpers.resolve_namespace(client, namespace))
  Ok(paths.resource_path(apps_v1, Some(ns), resource, name))
}
