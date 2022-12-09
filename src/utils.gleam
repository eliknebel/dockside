import gleam/json
import gleam/list
import gleam/string
import gleam/dynamic.{DecodeError, string}

pub fn prettify_json_decode_error(error: json.DecodeError) {
  case error {
    json.UnexpectedEndOfInput -> "JSON DecodeError: UnexpectedEndOfInput"
    json.UnexpectedByte(_byte, _position) -> "JSON DecodeError: UnexpectedByte"
    json.UnexpectedSequence(_byte, _position) ->
      "JSON DecodeError: UnexpectedSequence"
    json.UnexpectedFormat(decode_errors) ->
      list.map(
        decode_errors,
        fn(e) {
          let DecodeError(expected: expected, found: found, path: path) = e
          string.concat([
            "expected ",
            expected,
            " but found ",
            found,
            " at ",
            string.join(path, "/"),
          ])
        },
      )
      |> string.join(",")
  }
}
