import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string

pub fn prettify_json_decode_error(error: json.DecodeError) {
  case error {
    json.UnexpectedEndOfInput -> "JSON DecodeError: UnexpectedEndOfInput"
    json.UnexpectedByte(_) -> "JSON DecodeError: UnexpectedByte"
    json.UnexpectedSequence(_) -> "JSON DecodeError: UnexpectedSequence"
    json.UnableToDecode(decode_errors) ->
      list.map(decode_errors, fn(e) {
        let decode.DecodeError(expected: expected, found: found, path: path) = e
        string.concat([
          "expected ",
          expected,
          " but found ",
          found,
          " at ",
          string.join(path, "/"),
        ])
      })
      |> string.join(",")
  }
}
