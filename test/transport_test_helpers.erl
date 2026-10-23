-module(transport_test_helpers).
-export([timed_timeout/1, cancel/1, read_file/1, write_file/2, cancel_waits_for_owner/5, cancel_active/4, guardian_failure/4]).
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

%% The test alone inspects the opaque handle to pause guardian scheduling.
%% Public cancellation must not acknowledge caller DOWN while cleanup is blocked.
cancel_waits_for_owner(Prepare, Await, Cancel, Ready, Replacement) ->
    Parent = self(),
    {Caller, CallerRef} = spawn_monitor(fun() ->
        {ok, Pending} = Prepare(),
        Parent ! {prepared, self(), Pending},
        receive execute -> Await(Pending) end
    end),
    receive {prepared, Caller, Pending} ->
        {http_request, {request, Guardian, _, _, _}} = Pending,
        Caller ! execute,
        {ok, _} = Ready(),
        true = erlang:suspend_process(Guardian),
        {Canceller, CancelRef} = spawn_monitor(fun() ->
            Parent ! {cancelled, Cancel(Pending)}
        end),
        try
            exit(Caller, kill),
            receive {'DOWN', CallerRef, process, Caller, _} -> ok after 1000 -> error(caller_stuck) end,
            receive {cancelled, _} -> error(early_acknowledgment) after 100 -> ok end,
            true = erlang:resume_process(Guardian),
            receive {cancelled, {ok, nil}} -> ok after 1000 -> error(cancellation_stuck) end,
            receive {'DOWN', CancelRef, process, Canceller, normal} -> ok after 1000 -> error(canceller_stuck) end,
            %% No extra delay between cancellation acknowledgment and replacement.
            {ok, {response, 200, _, <<"no overlap">>}} = Replacement(),
            {ok, nil} = Cancel(Pending),
            true
        after
            catch erlang:resume_process(Guardian),
            exit(Caller, kill),
            exit(Canceller, kill),
            catch Cancel(Pending)
        end
    after 1000 -> exit(Caller, kill), error(prepare_stuck)
    end.

%% The active creator observes a typed cancellation result, without dying first.
cancel_active(Prepare, Await, Cancel, Ready) ->
    Parent = self(),
    {Caller, Ref} = spawn_monitor(fun() ->
        {ok, Pending} = Prepare(),
        Parent ! {prepared, self(), Pending},
        receive execute -> Parent ! {result, Await(Pending)} end
    end),
    receive {prepared, Caller, Pending} ->
        try
            Caller ! execute,
            {ok, _} = Ready(),
            {ok, nil} = Cancel(Pending),
            receive {result, {error, {transport, cancelled}}} -> ok after 1000 -> error(missing_cancel_result) end,
            receive {'DOWN', Ref, process, Caller, normal} -> ok after 1000 -> error(caller_stuck) end,
            {ok, nil} = Cancel(Pending),
            true
        after
            exit(Caller, kill),
            catch Cancel(Pending)
        end
    after 1000 -> exit(Caller, kill), error(prepare_stuck)
    end.

%% A dead guardian is not proof of cleanup. Late cancellation must fail closed
%% even though monitoring it now produces noproc rather than its original reason.
guardian_failure(Prepare, Await, Cancel, Ready) ->
    Parent = self(),
    {Caller, Ref} = spawn_monitor(fun() ->
        {ok, Pending} = Prepare(),
        Parent ! {prepared, self(), Pending},
        receive execute -> Parent ! {result, Await(Pending)} end
    end),
    receive {prepared, Caller, Pending} ->
        {http_request, {request, Guardian, _, _, _}} = Pending,
        GuardianRef = monitor(process, Guardian),
        try
            Caller ! execute,
            {ok, _} = Ready(),
            exit(Guardian, kill),
            receive {'DOWN', GuardianRef, process, Guardian, killed} -> ok after 1000 -> error(guardian_stuck) end,
            {error, {transport, unavailable}} = Cancel(Pending),
            {error, {transport, unavailable}} = Cancel(Pending),
            receive {result, {error, {transport, unavailable}}} -> ok after 1000 -> error(missing_failure_result) end,
            receive {'DOWN', Ref, process, Caller, normal} -> ok after 1000 -> error(caller_stuck) end,
            true
        after
            exit(Guardian, kill),
            exit(Caller, kill)
        end
    after 1000 -> exit(Caller, kill), error(prepare_stuck)
    end.
