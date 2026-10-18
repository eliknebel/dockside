-module(transport_test_helpers).
-export([timed_timeout/1, cancel/1, read_file/1, write_file/2]).
timed_timeout(Request) ->
    Start = erlang:monotonic_time(millisecond),
    Result = Request(),
    Elapsed = erlang:monotonic_time(millisecond) - Start,
    timer:sleep(100),
    Result =:= {error, {transport, timeout}} andalso Elapsed >= 200 andalso Elapsed < 1500.
cancel(Request) ->
    {Pid, Ref} = spawn_monitor(Request),
    timer:sleep(200),
    exit(Pid, kill),
    receive {'DOWN', Ref, process, Pid, _} -> ok end,
    timer:sleep(300),
    nil.

read_file(Path) -> {ok, Bytes} = file:read_file(Path), Bytes.
write_file(Path, Bytes) -> ok = file:write_file(Path, Bytes), nil.
