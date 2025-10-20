import dockside/k8s
import dockside/k8s/apps
import dockside/k8s/core
import dockside/k8s/options
import dockside/k8s/paths
import dockside/k8s/request_helpers
import gleam/dynamic/decode
import gleam/http.{Get, Http, Https, Post, Put}
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn from_url_parses_test() {
  k8s.from_url("https://cluster.local:6443/k8s")
  |> should.equal(
    Ok(
      k8s.K8sHttp(
        scheme: Https,
        host: "cluster.local",
        port: option.Some(6443),
        base_path: "/k8s",
        default_namespace: option.None,
        default_headers: [
          #("accept", "application/json"),
          #("user-agent", "dockside-k8s"),
        ],
      ),
    ),
  )
}

pub fn from_url_invalid_scheme_test() {
  k8s.from_url("ftp://cluster.local")
  |> should.equal(Error(k8s.InvalidUrl("Unsupported scheme in URL: ftp")))
}

pub fn add_header_overrides_test() {
  let client =
    k8s.K8sHttp(
      scheme: Https,
      host: "cluster.local",
      port: option.None,
      base_path: "",
      default_namespace: option.None,
      default_headers: [
        #("accept", "application/json"),
        #("user-agent", "dockside-k8s"),
      ],
    )

  k8s.add_header(client, "ACCEPT", "application/yaml")
  |> should.equal(
    k8s.K8sHttp(
      scheme: Https,
      host: "cluster.local",
      port: option.None,
      base_path: "",
      default_namespace: option.None,
      default_headers: [
        #("accept", "application/yaml"),
        #("user-agent", "dockside-k8s"),
      ],
    ),
  )
}

pub fn send_request_combines_headers_test() {
  let client =
    k8s.K8sMock(
      base_path: "/api",
      default_namespace: option.None,
      default_headers: [#("accept", "application/json")],
      mock_fn: fn(method, path, query, body, headers) {
        should.equal(method, Get)
        should.equal(path, "/api/pods")
        should.equal(query, [#("watch", "true")])
        should.equal(body, option.None)
        should.equal(headers, [
          #("accept", "application/json"),
          #("x-test", "yes"),
        ])

        Ok(response.Response(
          status: 200,
          headers: [],
          body: "{\"kind\":\"PodList\"}",
        ))
      },
    )

  k8s.send_request(
    client,
    Get,
    "/pods",
    [#("watch", "true")],
    [#("x-test", "yes")],
    option.None,
  )
  |> request_helpers.expect_body
  |> should.equal(Ok("{\"kind\":\"PodList\"}"))
}

pub fn expect_body_maps_errors_test() {
  request_helpers.expect_body(Error(k8s.InvalidUrl("bad")))
  |> should.equal(Error("Invalid Kubernetes API URL: bad"))

  request_helpers.expect_body(
    Ok(response.Response(status: 200, headers: [], body: "{\"status\":\"ok\"}")),
  )
  |> should.equal(Ok("{\"status\":\"ok\"}"))
}

pub fn expect_json_decodes_test() {
  request_helpers.expect_json(
    Ok(response.Response(
      status: 200,
      headers: [],
      body: "{\"name\":\"kube-system\"}",
    )),
    decode.at(["name"], decode.string),
  )
  |> should.equal(Ok("kube-system"))
}

pub fn resolve_namespace_priority_test() {
  let client =
    k8s.K8sHttp(
      scheme: Https,
      host: "api",
      port: option.None,
      base_path: "",
      default_namespace: option.Some("default"),
      default_headers: [],
    )

  request_helpers.resolve_namespace(client, option.Some("custom"))
  |> should.equal(Ok("custom"))

  request_helpers.resolve_namespace(client, option.None)
  |> should.equal(Ok("default"))

  request_helpers.resolve_namespace(
    k8s.K8sHttp(
      scheme: Http,
      host: "api",
      port: option.None,
      base_path: "",
      default_namespace: option.None,
      default_headers: [],
    ),
    option.None,
  )
  |> should.equal(Error(
    "Namespace required. Pass one explicitly or configure a default on the client.",
  ))
}

pub fn list_options_to_query_test() {
  options.ListOptions(
    label_selector: option.Some("app=test"),
    field_selector: option.Some("status.phase=Running"),
    limit: option.Some(50),
    continue_token: option.Some("token"),
    resource_version: option.Some("42"),
  )
  |> options.to_query
  |> should.equal([
    #("labelSelector", "app=test"),
    #("fieldSelector", "status.phase=Running"),
    #("continue", "token"),
    #("resourceVersion", "42"),
    #("limit", "50"),
  ])
}

pub fn list_options_extend_with_test() {
  let query =
    options.extend_with(
      [#("existing", "true")],
      options.ListOptions(
        label_selector: option.None,
        field_selector: option.None,
        limit: option.Some(5),
        continue_token: option.None,
        resource_version: option.None,
      ),
    )

  should.equal(query, [#("existing", "true"), #("limit", "5")])
}

pub fn paths_helpers_test() {
  should.equal(
    paths.namespaced_collection_path(paths.Core("v1"), "default", "pods"),
    "/api/v1/namespaces/default/pods",
  )

  should.equal(
    paths.resource_path(
      paths.Named(group: "batch", version: "v1"),
      option.Some("team a"),
      "jobs",
      "nightly build",
    ),
    "/apis/batch/v1/namespaces/team%20a/jobs/nightly%20build",
  )
}

pub fn core_list_pods_calls_test() {
  let client =
    k8s.K8sMock(
      base_path: "",
      default_namespace: option.None,
      default_headers: [#("accept", "application/json")],
      mock_fn: fn(method, path, query, body, headers) {
        should.equal(method, Get)
        should.equal(path, "/api/v1/namespaces/default/pods")
        should.equal(query, [])
        should.equal(body, option.None)
        should.equal(headers, [#("accept", "application/json")])

        Ok(response.Response(
          status: 200,
          headers: [],
          body: "{\"kind\":\"PodList\"}",
        ))
      },
    )

  core.list_pods(client, option.Some("default"), options.default_list_options())
  |> should.equal(Ok("{\"kind\":\"PodList\"}"))
}

pub fn core_create_pod_sets_headers_test() {
  let client =
    k8s.K8sMock(
      base_path: "",
      default_namespace: option.None,
      default_headers: [],
      mock_fn: fn(method, path, query, body, headers) {
        should.equal(method, Post)
        should.equal(path, "/api/v1/namespaces/default/pods")
        should.equal(query, [])
        should.equal(body, option.Some("{\"apiVersion\":\"v1\"}"))
        should.equal(headers, [#("content-type", "application/json")])

        Ok(response.Response(
          status: 201,
          headers: [],
          body: "{\"kind\":\"Pod\"}",
        ))
      },
    )

  core.create_pod(
    client,
    option.Some("default"),
    json.object([
      #("apiVersion", json.string("v1")),
    ]),
  )
  |> should.equal(Ok("{\"kind\":\"Pod\"}"))
}

pub fn core_pod_logs_query_test() {
  let client =
    k8s.K8sMock(
      base_path: "",
      default_namespace: option.None,
      default_headers: [],
      mock_fn: fn(_method, _path, query, _body, _headers) {
        should.equal(
          list.sort(query, by: fn(a, b) { string.compare(a.0, b.0) }),
          list.sort(
            [
              #("container", "app"),
              #("follow", "true"),
              #("limitBytes", "1024"),
              #("previous", "true"),
              #("sinceSeconds", "5"),
              #("tailLines", "10"),
              #("timestamps", "true"),
            ],
            by: fn(a, b) { string.compare(a.0, b.0) },
          ),
        )

        Ok(response.Response(status: 200, headers: [], body: "logs"))
      },
    )

  core.pod_logs(
    client,
    option.Some("default"),
    "app",
    core.PodLogOptions(
      container: option.Some("app"),
      follow: True,
      previous: True,
      timestamps: True,
      tail_lines: option.Some(10),
      since_seconds: option.Some(5),
      limit_bytes: option.Some(1024),
    ),
  )
  |> should.equal(Ok("logs"))
}

pub fn apps_replace_deployment_scale_test() {
  let client =
    k8s.K8sMock(
      base_path: "",
      default_namespace: option.None,
      default_headers: [],
      mock_fn: fn(method, path, query, body, headers) {
        should.equal(method, Put)
        should.equal(
          path,
          "/apis/apps/v1/namespaces/default/deployments/web/scale",
        )
        should.equal(query, [])
        should.equal(body, option.Some("{\"spec\":{\"replicas\":5}}"))
        should.equal(headers, [#("content-type", "application/json")])

        Ok(response.Response(
          status: 200,
          headers: [],
          body: "{\"kind\":\"Scale\"}",
        ))
      },
    )

  apps.replace_deployment_scale(
    client,
    option.Some("default"),
    "web",
    json.object([
      #("spec", json.object([#("replicas", json.int(5))])),
    ]),
  )
  |> should.equal(Ok("{\"kind\":\"Scale\"}"))
}

pub fn apps_list_daemon_sets_test() {
  let client =
    k8s.K8sMock(
      base_path: "",
      default_namespace: option.None,
      default_headers: [],
      mock_fn: fn(method, path, query, body, headers) {
        should.equal(method, Get)
        should.equal(path, "/apis/apps/v1/namespaces/default/daemonsets")
        should.equal(query, [#("labelSelector", "tier=backend")])
        should.equal(body, option.None)
        should.equal(headers, [])

        Ok(response.Response(
          status: 200,
          headers: [],
          body: "{\"kind\":\"DaemonSetList\"}",
        ))
      },
    )

  apps.list_daemon_sets(
    client,
    option.Some("default"),
    options.ListOptions(
      label_selector: option.Some("tier=backend"),
      field_selector: option.None,
      limit: option.None,
      continue_token: option.None,
      resource_version: option.None,
    ),
  )
  |> should.equal(Ok("{\"kind\":\"DaemonSetList\"}"))
}
