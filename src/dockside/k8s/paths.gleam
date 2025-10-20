import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri

pub type GroupVersion {
  Core(String)
  Named(group: String, version: String)
}

pub fn core(version: String) -> GroupVersion {
  Core(version)
}

pub fn named(group: String, version: String) -> GroupVersion {
  Named(group: group, version: version)
}

pub fn collection_path(group_version: GroupVersion, resource: String) -> String {
  prefix(group_version) <> "/" <> resource
}

pub fn namespaced_collection_path(
  group_version: GroupVersion,
  namespace: String,
  resource: String,
) -> String {
  prefix(group_version)
  <> "/namespaces/"
  <> encode_segment(namespace)
  <> "/"
  <> resource
}

pub fn resource_path(
  group_version: GroupVersion,
  namespace: Option(String),
  resource: String,
  name: String,
) -> String {
  let base = case namespace {
    Some(ns) -> namespaced_collection_path(group_version, ns, resource)
    None -> collection_path(group_version, resource)
  }

  base <> "/" <> encode_segment(name)
}

pub fn subresource_path(
  group_version: GroupVersion,
  namespace: Option(String),
  resource: String,
  name: String,
  subresource: String,
) -> String {
  resource_path(group_version, namespace, resource, name) <> "/" <> subresource
}

fn prefix(group_version: GroupVersion) -> String {
  case group_version {
    Core(version) -> "/api/" <> version
    Named(group: group, version: version) -> "/apis/" <> group <> "/" <> version
  }
}

fn encode_segment(value: String) -> String {
  value
  |> string.trim
  |> uri.percent_encode
}
