-module(example_ffi).

-export([example_ffi_fn/2]).

example_ffi_fn(Data, Key) ->
    case Data of
        #{Key := Value} -> {some, Value};
        _ -> none
    end.
