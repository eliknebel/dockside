-module(stream_test_helpers).
-export([run/9]).

prepare(Client, Name) ->
    'dockside@k8s@core':prepare_pod_log_stream(Client, <<"test">>, <<"pod">>, Name, 200).
start(H) -> 'dockside@k8s':start_stream(H).
next(H) -> 'dockside@k8s':next_chunk(H).
cancel(H) -> 'dockside@k8s':cancel_stream(H).
get(Client, Path) -> 'dockside@k8s':send_request(Client, get, Path, [], [], none).

run(Http, Tls, Raw, RawTls, Wrong, Untrusted, Ca, WrongCa, Handshake) ->
    {error, {transport, invalid_options}} = 'dockside@k8s@core':prepare_pod_log_stream(Http, <<"test">>, <<"pod">>, <<>>, 200),
    {error, {transport, invalid_options}} = 'dockside@k8s@core':prepare_pod_log_stream(Http, <<"test">>, <<"pod">>, <<"x">>, 0),
    {ok, Unstarted} = prepare(Http, <<"never">>),
    {error, {transport, invalid_options}} = next(Unstarted),
    {ok, nil} = cancel(Unstarted), {ok, nil} = cancel(Unstarted),
    {error, {transport, cancelled}} = start(Unstarted),
    lists:foreach(fun(Client) ->
        fragments(Client),
        finite(Client),
        status(Client, <<"denied">>, 403),
        status(Client, <<"redirect">>, 302),
        timeout(Client),
        lists:foreach(fun(Where) ->
            cancellation(Client, Where, cancel),
            cancellation(Client, Where, creator_death)
        end, [prepared, headers, body]),
        delayed_receipt(Client),
        guardian_failure(Client),
        distinct(Client)
    end, [Http, Tls]),
    lists:foreach(fun(Client) ->
        framing(Client), resource(Client)
    end, [Raw, RawTls]),
    {ok, BadTrust} = prepare(Untrusted, <<"finite">>),
    {error, {transport, tls}} = start(BadTrust), {ok, nil} = cancel(BadTrust),
    {ok, BadHost} = prepare(Wrong, <<"finite">>),
    {error, {transport, tls}} = start(BadHost), {ok, nil} = cancel(BadHost),
    {ok, Original} = file:read_file(Ca), {ok, Other} = file:read_file(WrongCa),
    try
        ok = file:write_file(Ca, Other),
        {ok, Rotated} = prepare(Tls, <<"finite">>),
        {error, {transport, tls}} = start(Rotated), {ok, nil} = cancel(Rotated)
    after ok = file:write_file(Ca, Original) end,
    finite(Tls),
    timeout(Handshake),
    handshake(Http, Handshake, cancel),
    handshake(Http, Handshake, creator_death),
    %% A quiet follow exceeds both the default finite 10s and application 30s
    %% sweep deadline. Its next read remains interruptible throughout this wait.
    {ok, Quiet} = prepare(Tls, <<"quiet">>), {ok, _} = start(Quiet),
    timer:sleep(31000),
    {ok, {chunk, <<"awake">>}} = next(Quiet),
    {ok, nil} = cancel(Quiet),
    io:format("HTTP/TLS stream ownership, framing, safe errors and 31-second quiet lifetime passed.~n"),
    nil.

fragments(Client) ->
    {ok, H} = prepare(Client, <<"fragments">>),
    T = erlang:monotonic_time(millisecond),
    {ok, {response,200,_,nil}} = start(H),
    {error, {transport, invalid_options}} = start(H),
    {ok, {chunk, <<"first">>}} = next(H),
    {ok, {chunk, <<"second">>}} = next(H),
    true = erlang:monotonic_time(millisecond) - T < 1000,
    Parent = self(), spawn(fun() -> Parent ! {foreign, next(H)} end),
    receive {foreign, {error, {transport, invalid_options}}} -> ok after 1000 -> error(foreign_reader) end,
    {ok, nil} = cancel(H), {ok, nil} = cancel(H).

finite(Client) ->
    {ok, H} = prepare(Client, <<"finite">>), {ok, _} = start(H),
    <<"finite body">> = collect(H, <<>>),
    {ok, nil} = cancel(H), {ok, nil} = cancel(H).
collect(H, Acc) ->
    case next(H) of
        {ok, {chunk, B}} -> collect(H, <<Acc/binary,B/binary>>);
        {ok, 'end'} -> Acc
    end.
status(Client, Name, Status) ->
    {ok, H} = prepare(Client, Name),
    T = erlang:monotonic_time(millisecond),
    {error, {unexpected_status, Status, <<>>}} = start(H),
    true = erlang:monotonic_time(millisecond) - T < 1000,
    {ok, nil} = cancel(H).
timeout(Client) ->
    {ok, H} = prepare(Client, <<"headers">>),
    T = erlang:monotonic_time(millisecond),
    {error, {transport, timeout}} = start(H),
    Elapsed = erlang:monotonic_time(millisecond) - T,
    true = Elapsed >= 900 andalso Elapsed < 2500,
    {ok, nil} = cancel(H).

cancellation(Client, Where, How) ->
    Parent = self(),
    {Creator, Ref} = spawn_monitor(fun() ->
        Name = case Where of headers -> <<"headers">>; _ -> <<"body">> end,
        {ok, H} = prepare(Client, Name), Parent ! {prepared, self(), H},
        receive go -> ok end,
        case Where of
            prepared -> receive stop -> ok end;
            headers -> Parent ! {result, start(H)};
            body -> {ok, _} = start(H), Parent ! {reading, self()}, Parent ! {result, next(H)}
        end
    end),
    H = receive {prepared, Creator, Handle} -> Handle after 2000 -> error(prepare_stuck) end,
    Creator ! go,
    case Where of
        headers -> {ok, _} = get(Client, <<"/wait/headers">>);
        body -> receive {reading, Creator} -> ok after 2000 -> error(open_stuck) end;
        prepared -> ok
    end,
    case How of
        creator_death ->
            exit(Creator, kill),
            receive {'DOWN', Ref, process, Creator, killed} -> ok after 2000 -> error(creator_stuck) end;
        cancel -> ok
    end,
    {ok, nil} = cancel(H), {ok, nil} = cancel(H),
    case {How, Where} of
        {cancel, prepared} -> Creator ! stop;
        {cancel, _} -> receive {result, {error, {transport, cancelled}}} -> ok after 2000 -> error(cancel_result) end;
        _ -> ok
    end,
    case How of cancel -> receive {'DOWN', Ref, process, Creator, normal} -> ok after 2000 -> error(creator_stuck) end; _ -> ok end,
    {ok, {response,200,_,<<"closed">>}} = get(Client, <<"/closed">>).

delayed_receipt(Client) ->
    Parent = self(),
    Creator = spawn(fun() ->
        {ok, H} = prepare(Client, <<"body">>), {ok, _} = start(H),
        Parent ! {ready, self(), H}, next(H)
    end),
    H = receive {ready, Creator, Handle} -> Handle after 2000 -> error(no_ready) end,
    {http_stream, {stream, Guardian, _, _, _}} = H,
    true = erlang:suspend_process(Guardian),
    spawn(fun() -> Parent ! {cancelled, cancel(H)} end),
    exit(Creator, kill),
    receive {cancelled, _} -> error(early_receipt) after 100 -> ok end,
    true = erlang:resume_process(Guardian),
    receive {cancelled, {ok, nil}} -> ok after 2000 -> error(no_receipt) end,
    {ok, {response,200,_,<<"closed">>}} = get(Client, <<"/closed">>).

guardian_failure(Client) ->
    Parent = self(),
    Creator = spawn(fun() ->
        {ok, H} = prepare(Client, <<"body">>), {ok, _} = start(H),
        Parent ! {ready, self(), H}, next(H)
    end),
    H = receive {ready, Creator, Handle} -> Handle after 2000 -> error(no_ready) end,
    {http_stream, {stream, Guardian, _, _, _}} = H,
    M = monitor(process, Guardian), exit(Guardian, kill),
    receive {'DOWN', M, process, Guardian, killed} -> ok after 2000 -> error(no_down) end,
    {error, {transport, unavailable}} = cancel(H),
    {error, {transport, unavailable}} = cancel(H),
    {ok, {response,200,_,<<"closed">>}} = get(Client, <<"/closed">>).

distinct(Client) ->
    lists:foreach(fun(Name) ->
        Fresh = 'dockside@k8s':with_bearer_token(Client, Name),
        {ok, H} = prepare(Fresh, Name), {ok, _} = start(H),
        Name = collect(H, <<>>), {ok, nil} = cancel(H)
    end, [<<"container-a">>, <<"container-b">>]).

framing(Client) ->
    lists:foreach(fun(Name) ->
        {ok, H} = prepare(Client, Name),
        {error, {transport, unavailable}} = start(H), {ok, nil} = cancel(H)
    end, [<<"encoding">>, <<"ambiguous">>]),
    lists:foreach(fun(Name) ->
        {ok, H} = prepare(Client, Name), {ok, _} = start(H),
        <<"hello">> = collect(H, <<>>), {ok, nil} = cancel(H)
    end, [<<"length">>, <<"eof">>, <<"split">>, <<"trailers">>]),
    lists:foreach(fun(Name) ->
        {ok, H} = prepare(Client, Name), {ok, _} = start(H),
        expect_error(H), {ok, nil} = cancel(H)
    end, [<<"bad-size">>, <<"truncated">>, <<"bad-crlf">>, <<"long-size">>, <<"long-trailer">>]).
expect_error(H) ->
    case next(H) of
        {ok, {chunk, _}} -> expect_error(H);
        {error, {transport, unavailable}} -> ok;
        Other -> error({unexpected_framing_result, Other})
    end.

resource(Client) ->
    {ok, H} = prepare(Client, <<"large">>), {ok, _} = start(H),
    {http_stream, {stream, Guardian, _, _, _}} = H,
    {links, [Owner]} = process_info(Guardian, links),
    erlang:garbage_collect(), Base = erlang:memory(binary),
    T = erlang:monotonic_time(millisecond),
    {Total, Largest, MaxRefs} = consume(H, Owner, 0, 0, 0),
    true = erlang:monotonic_time(millisecond) - T < 10000,
    true = Largest =< 65536,
    true = MaxRefs < 2 * 1024 * 1024,
    %% Stop requesting chunks while the peer continues sending. Sampling the
    %% entire VM includes TLS/socket buffering outside the reader's own heap.
    erlang:garbage_collect(Owner), erlang:garbage_collect(),
    timer:sleep(600),
    {binary, HeldRefs} = process_info(Owner, binary),
    Held = lists:sum([S || {_,S,_} <- HeldRefs]),
    true = Held =< 2 * 65536,
    Growth = erlang:memory(binary) - Base,
    true = Growth < 4 * 1024 * 1024,
    io:format("bounded oversized chunk: bytes=~p largest=~p owner_binary_refs=~p held_after_gc=~p VM_binary_growth=~p~n", [Total,Largest,MaxRefs,Held,Growth]),
    {ok, nil} = cancel(H), false = is_process_alive(Owner), false = is_process_alive(Guardian).
consume(_, _, N, Largest, MaxRefs) when N >= 4 * 1024 * 1024 -> {N,Largest,MaxRefs};
consume(H, Owner, N, Largest, MaxRefs) ->
    {ok, {chunk, Bytes}} = next(H),
    true = binary:referenced_byte_size(Bytes) =:= byte_size(Bytes),
    {binary, Refs} = process_info(Owner, binary),
    Size = lists:sum([S || {_,S,_} <- Refs]),
    consume(H, Owner, N + byte_size(Bytes), max(Largest,byte_size(Bytes)), max(MaxRefs,Size)).

handshake(Http, Client, How) ->
    Parent = self(),
    {Creator, Ref} = spawn_monitor(fun() ->
        {ok, H} = prepare(Client, <<"body">>),
        Parent ! {prepared, self(), H}, Parent ! {result, start(H)}
    end),
    H = receive {prepared, Creator, Handle} -> Handle after 2000 -> error(no_handle) end,
    {ok, _} = get(Http, <<"/wait-handshake">>),
    case How of creator_death -> exit(Creator, kill); cancel -> ok end,
    {ok, nil} = cancel(H), {ok, nil} = cancel(H),
    case How of
        cancel -> receive {result, {error, {transport, cancelled}}} -> ok after 2000 -> error(no_cancel) end;
        creator_death -> ok
    end,
    receive {'DOWN', Ref, process, Creator, _} -> ok after 2000 -> error(no_creator_exit) end,
    {ok, {response,200,_,<<"closed">>}} = get(Http, <<"/handshake-closed">>).
