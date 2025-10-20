import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

pub type ListOptions {
  ListOptions(
    label_selector: Option(String),
    field_selector: Option(String),
    limit: Option(Int),
    continue_token: Option(String),
    resource_version: Option(String),
  )
}

pub fn default_list_options() -> ListOptions {
  ListOptions(
    label_selector: None,
    field_selector: None,
    limit: None,
    continue_token: None,
    resource_version: None,
  )
}

pub fn to_query(options: ListOptions) -> List(#(String, String)) {
  let ListOptions(
    label_selector: label_selector,
    field_selector: field_selector,
    limit: limit,
    continue_token: continue_token,
    resource_version: resource_version,
  ) = options

  []
  |> append_optional("labelSelector", label_selector)
  |> append_optional("fieldSelector", field_selector)
  |> append_optional("continue", continue_token)
  |> append_optional("resourceVersion", resource_version)
  |> append_int_option("limit", limit)
}

pub fn extend_with(
  query: List(#(String, String)),
  options: ListOptions,
) -> List(#(String, String)) {
  list.append(query, to_query(options))
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

fn append_int_option(
  query: List(#(String, String)),
  key: String,
  value: Option(Int),
) -> List(#(String, String)) {
  case value {
    Some(v) -> list.append(query, [#(key, int.to_string(v))])
    None -> query
  }
}
