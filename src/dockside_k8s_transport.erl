-module(dockside_k8s_transport).
-export([send/5, prepare/5, await/1, cancel/1]).

%% A prepared request starts no connection. Its creator can register the handle
%% with a lifecycle owner before await starts I/O; cancellation then always has
%% an explicit acknowledgment, including when the creator is concurrently dying.
prepare(Method, Url, Headers, Body,
        {options, Ca, Verify, Connect, Read, Deadline, Redirects})
  when is_integer(Connect), Connect > 0, Connect =< 4294967295,
       is_integer(Read), Read > 0, Read =< 4294967295,
       is_integer(Deadline), Deadline > 0, Deadline =< 4294967295 ->
    Caller = self(),
    Token = make_ref(),
    %% A monitor reports noproc after any earlier exit, including an unclean kill.
    %% Keep a completion receipt in the handle so late cancel can distinguish it.
    %% The atomic is garbage-collected with the handle; no tracker process survives.
    Completed = atomics:new(1, []),
    Guardian = spawn(fun() ->
        process_flag(trap_exit, true),
        CallerRef = monitor(process, Caller),
        receive
            {execute, Token, Caller} ->
                Worker = spawn_link(fun() ->
                    Result = try
                        Options = [{pool, false}, {with_body, true},
                                   {connect_timeout, min(Connect, Deadline)},
                                   {recv_timeout, min(Read, Deadline)},
                                   {follow_redirect, Redirects},
                                   {ssl_options, ssl_options(Ca, Verify)}],
                        response(hackney:request(Method, Url, Headers, Body, Options))
                    catch _:_ -> {error, unavailable}
                    end,
                    exit({completed, Result})
                end),
                running(Caller, CallerRef, Worker, Token, Deadline, Completed);
            {cancel, Token} -> finish(Completed, {completed, {error, cancelled}});
            {'DOWN', CallerRef, process, Caller, _} -> finish(Completed, normal)
        end
    end),
    {ok, {request, Guardian, Token, Caller, Completed}};
prepare(_, _, _, _, _) -> {error, invalid_options}.

running(Caller, CallerRef, Worker, Token, Deadline, Completed) ->
    receive
        {'EXIT', Worker, {completed, Result}} ->
            demonitor(CallerRef, [flush]),
            finish(Completed, {completed, Result});
        {'EXIT', Worker, _} -> finish(Completed, {completed, {error, unavailable}});
        {cancel, Token} ->
            stop_worker(Worker),
            finish(Completed, {completed, {error, cancelled}});
        {'DOWN', CallerRef, process, Caller, _} ->
            stop_worker(Worker), finish(Completed, normal)
    after Deadline ->
        stop_worker(Worker),
        finish(Completed, {completed, {error, timeout}})
    end.

%% Only the creator may await; this prevents unowned execution after transfer.
%% The monitor is installed before execution can complete.
await({request, Guardian, Token, Caller, _}) when Caller =:= self() ->
    Ref = monitor(process, Guardian),
    Guardian ! {execute, Token, Caller},
    receive
        {'DOWN', Ref, process, Guardian, {completed, Result}} -> Result;
        {'DOWN', Ref, process, Guardian, _} -> {error, unavailable}
    end;
await(_) -> {error, invalid_options}.

%% Any holder may cancel. A successful return means this guardian has completed
%% its connection-owner shutdown; caller DOWN alone does not provide that guarantee.
%% No connection is started by cancellation; repeated cancellation is harmless.
cancel({request, Guardian, Token, _, Completed}) ->
    Ref = monitor(process, Guardian),
    Guardian ! {cancel, Token},
    receive
        {'DOWN', Ref, process, Guardian, _} ->
            case atomics:get(Completed, 1) of
                1 -> {ok, nil};
                0 -> {error, unavailable}
            end
    end.

%% Called only with no connection started or after the worker's EXIT signal.
finish(Completed, Reason) ->
    atomics:put(Completed, 1, 1),
    exit(Reason).

send(Method, Url, Headers, Body, Options) ->
    case prepare(Method, Url, Headers, Body, Options) of
        {ok, Request} -> await(Request);
        Error -> Error
    end.

stop_worker(Worker) ->
    exit(Worker, kill),
    receive {'EXIT', Worker, _} -> ok end.

ssl_options(Ca, Verify) ->
    Trust = case Ca of
        none -> [{cacerts, public_key:cacerts_get()}];
        {some, File} ->
            %% Decode on every request, avoiding OTP's filename-based PEM cache
            %% so projected CA rotation takes effect immediately.
            {ok, Pem} = file:read_file(File),
            Certs = [Der || {'Certificate', Der, not_encrypted} <- public_key:pem_decode(Pem)],
            true = Certs =/= [],
            [{cacerts, Certs}]
    end,
    case Verify of
        true -> [{verify, verify_peer},
                 %% Hackney otherwise adds a certifi-backed partial_chain hook,
                 %% which would expand trust beyond the selected CA/system roots.
                 {partial_chain, fun(_) -> unknown_ca end},
                 {customize_hostname_check,
                  [{match_fun, public_key:pkix_verify_hostname_match_fun(https)}]} | Trust];
        false -> [{verify, verify_none} | Trust]
    end.

response({ok, Status, Headers, Body}) -> {ok, {response, Status, Headers, Body}};
response({ok, Status, Headers}) -> {ok, {response, Status, Headers, <<>>}};
response({error, Reason}) -> {error, category(Reason)}.

category(timeout) -> timeout;
category(connect_timeout) -> timeout;
category({tls_alert, _}) -> tls;
category({ssl, _}) -> tls;
category({options, _}) -> tls;
category(_) -> unavailable.
