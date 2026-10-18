-module(dockside_k8s_transport).
-export([send/5]).

%% A guardian bounds the entire operation, including DNS, TLS, and trickling
%% bodies. It also cancels the connection owner when the calling process dies.
%% No process changes the caller's trap_exit flag or global Hackney options.
send(Method, Url, Headers, Body,
     {options, Ca, Verify, Connect, Read, Deadline, Redirects})
  when is_integer(Connect), Connect > 0, Connect =< 4294967295,
       is_integer(Read), Read > 0, Read =< 4294967295,
       is_integer(Deadline), Deadline > 0, Deadline =< 4294967295 ->
    Caller = self(),
    {Guardian, Ref} = spawn_monitor(fun() ->
        process_flag(trap_exit, true),
        CallerRef = monitor(process, Caller),
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
        receive
            {'EXIT', Worker, {completed, Result}} ->
                demonitor(CallerRef, [flush]),
                exit({completed, Result});
            {'EXIT', Worker, _} -> exit({completed, {error, unavailable}});
            {'DOWN', CallerRef, process, Caller, _} ->
                stop_worker(Worker), exit(normal)
        after Deadline ->
            stop_worker(Worker),
            exit({completed, {error, timeout}})
        end
    end),
    receive
        {'DOWN', Ref, process, Guardian, {completed, Result}} -> Result;
        {'DOWN', Ref, process, Guardian, _} -> {error, unavailable}
    end;
send(_, _, _, _, _) -> {error, invalid_options}.

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
