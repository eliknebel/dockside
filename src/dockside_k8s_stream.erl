%% Owned pull transport. Hackney 1.25 handles request construction and verified
%% connection setup. Its body parser waits for an entire advertised HTTP chunk;
%% the raw handoff below instead frames available bytes without that allocation.
%% Application source identity, retries and presentation stay in Gleam callers.
-module(dockside_k8s_stream).
-export([prepare/5, start/1, next/1, cancel/1]).
-include_lib("hackney/include/hackney.hrl").
-define(CHUNK, 65536).
-define(FRAME_LINE, 8192).
-define(TRAILERS, 16384).

prepare(Method, Url, Headers, Body,
        Options = {options, _, true, Connect, Read, Deadline, false})
  when is_integer(Connect), Connect > 0, Connect =< 4294967295,
       is_integer(Read), Read > 0, Read =< 4294967295,
       is_integer(Deadline), Deadline > 0, Deadline =< 4294967295 ->
    Caller = self(), Token = make_ref(), Completed = atomics:new(1, []),
    Guardian = spawn(fun() ->
        process_flag(trap_exit, true),
        Monitor = monitor(process, Caller),
        prepared(Caller, Monitor, Token, Completed,
                 fun() -> open(Method, Url, Headers, Body, Options) end, Deadline)
    end),
    {ok, {stream, Guardian, Token, Caller, Completed}};
prepare(_, _, _, _, _) -> {error, invalid_options}.

prepared(Caller, Monitor, Token, Completed, Open, Deadline) ->
    receive
        {call, Token, Caller, Ref, start} ->
            Guardian = self(),
            Worker = spawn_link(fun() ->
                try owner(Guardian, Open())
                catch
                    exit:{finished, Result} -> exit({finished, Result});
                    _:_ -> exit({finished, {error, unavailable}})
                end
            end),
            opening(Caller, Monitor, Token, Completed, Worker, Ref,
                    erlang:monotonic_time(millisecond) + Deadline);
        {call, Token, Caller, Ref, _} ->
            Caller ! {Ref, {error, invalid_options}},
            prepared(Caller, Monitor, Token, Completed, Open, Deadline);
        {cancel, Token} -> finish(Completed, 2);
        {'DOWN', Monitor, process, Caller, _} -> finish(Completed, 2)
    end.

opening(Caller, Monitor, Token, Completed, Worker, Ref, Deadline) ->
    Remaining = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {opened, Worker, Head} ->
            case erlang:monotonic_time(millisecond) =< Deadline of
                true ->
                    Caller ! {Ref, {ok, Head}},
                    active(Caller, Monitor, Token, Completed, Worker, none);
                false -> stop(Worker), finish(Completed, 3)
            end;
        {'EXIT', Worker, {finished, Result}} ->
            Caller ! {Ref, Result}, finish(Completed, 1);
        {'EXIT', Worker, _} -> finish(Completed, 1);
        {cancel, Token} -> stop(Worker), finish(Completed, 2);
        {'DOWN', Monitor, process, Caller, _} -> stop(Worker), finish(Completed, 2)
    after Remaining -> stop(Worker), finish(Completed, 3)
    end.

active(Caller, Monitor, Token, Completed, Worker, Pending) ->
    receive
        {call, Token, Caller, Ref, next} when Pending =:= none ->
            Worker ! next,
            active(Caller, Monitor, Token, Completed, Worker, Ref);
        {call, Token, Caller, Ref, _} ->
            Caller ! {Ref, {error, invalid_options}},
            active(Caller, Monitor, Token, Completed, Worker, Pending);
        {chunk, Worker, Bytes} when Pending =/= none ->
            Caller ! {Pending, {ok, {chunk, Bytes}}},
            active(Caller, Monitor, Token, Completed, Worker, none);
        {'EXIT', Worker, {finished, Result}} ->
            Caller ! {Pending, Result}, finish(Completed, 1);
        {'EXIT', Worker, _} -> finish(Completed, 1);
        {cancel, Token} -> stop(Worker), finish(Completed, 2);
        {'DOWN', Monitor, process, Caller, _} -> stop(Worker), finish(Completed, 2)
    end.

start(Handle) -> call(Handle, start).
next(Handle) -> call(Handle, next).

%% Calls originate only from the creator, so at most one body read can be in
%% flight. A separate holder can cancel even while that creator is blocked here.
call({stream, Guardian, Token, Caller, Completed}, Operation) when Caller =:= self() ->
    Monitor = monitor(process, Guardian), Ref = make_ref(),
    Guardian ! {call, Token, Caller, Ref, Operation},
    receive
        {Ref, Result} -> demonitor(Monitor, [flush]), Result;
        {'DOWN', Monitor, process, Guardian, _} ->
            case atomics:get(Completed, 1) of
                2 -> {error, cancelled};
                3 -> {error, timeout};
                _ -> {error, unavailable}
            end
    end;
call(_, _) -> {error, invalid_options}.

cancel({stream, Guardian, Token, _, Completed}) ->
    Ref = monitor(process, Guardian),
    Guardian ! {cancel, Token},
    receive {'DOWN', Ref, process, Guardian, _} ->
        case atomics:get(Completed, 1) of
            0 -> {error, unavailable};
            _ -> {ok, nil}
        end
    end.

%% Set the receipt only after the connection owner exited (or never started).
%% A killed guardian leaves zero and linked ownership still closes its socket.
finish(Completed, Value) -> atomics:put(Completed, 1, Value), exit(normal).
stop(Worker) -> exit(Worker, kill), receive {'EXIT', Worker, _} -> ok end.

open(Method, Url, Headers, Body, {options, Ca, Verify, Connect, _Read, Deadline, _}) ->
    Options = [{pool, false}, {with_body, false},
               {connect_timeout, min(Connect, Deadline)},
               {recv_timeout, Deadline}, {follow_redirect, false},
               {connect_options, [{buffer, ?CHUNK}, {recbuf, ?CHUNK}]},
               {ssl_options, dockside_k8s_transport:ssl_options(Ca, Verify)}],
    case hackney:request(Method, Url, Headers, Body, Options) of
        {ok, Status, ResponseHeaders, Ref} ->
            %% cancel_request's buffer omits bytes already in the header parser.
            %% This is the sole Hackney-record dependency, pinned to 1.25.x and
            %% covered by coalesced-header/body tests. Detach before any body read.
            Client = hackney_manager:get_state(Ref),
            Buffered = hackney_http:get(Client#client.parser, buffer),
            {ok, {Transport, Socket, _, _}} = hackney:cancel_request(Ref),
            true = byte_size(Buffered) =< ?CHUNK,
            {ok, {response, Status, ResponseHeaders, nil},
             Transport, Socket, binary:copy(Buffered)};
        {error, Reason} -> {error, dockside_k8s_transport:category(Reason)}
    end.

owner(Guardian, {ok, Head = {response, Status, Headers, nil}, Transport, Socket, Buffer}) ->
    %% Refuse status bodies before framing or reading them. The Gleam boundary
    %% maps this head to a safe status error; it never sees an upstream error body.
    case Status >= 200 andalso Status < 300 of
        false ->
            Transport:close(Socket),
            exit({finished, {ok, Head}});
        true ->
            Mode = framing(Status, Headers),
            Guardian ! {opened, self(), Head},
            pull(Guardian, Transport, Socket, Mode, Buffer)
    end;
owner(_, Error) -> exit({finished, Error}).

pull(Guardian, Transport, Socket, Mode, Buffer) ->
    receive next ->
        case read_next(Transport, Socket, Mode, Buffer) of
            {chunk, Bytes, NextMode, Rest} ->
                Guardian ! {chunk, self(), binary:copy(Bytes)},
                pull(Guardian, Transport, Socket, NextMode, binary:copy(Rest));
            done -> Transport:close(Socket), exit({finished, {ok, 'end'}});
            {error, Error} -> Transport:close(Socket), exit({finished, {error, Error}})
        end
    end.

framing(204, _) -> done;
framing(_, Headers) ->
    Lower = [{string:lowercase(K), string:lowercase(V)} || {K,V} <- Headers],
    %% We request identity encoding; unsupported encoding cannot silently corrupt
    %% the byte stream. Ambiguous framing is rejected on this dedicated socket.
    Encoding = proplists:get_value(<<"content-encoding">>, Lower, <<"identity">>),
    true = Encoding =:= <<"identity">>,
    case {proplists:get_all_values(<<"transfer-encoding">>, Lower),
          proplists:get_all_values(<<"content-length">>, Lower)} of
        {[<<"chunked">>], []} -> size;
        {[], []} -> eof;
        {[], [Length]} ->
            N = binary_to_integer(Length),
            true = N >= 0, {length, N};
        _ -> error(invalid_framing)
    end.

read_next(_, _, done, _) -> done;
read_next(_, _, {length, 0}, _) -> done;
read_next(T, S, Mode, <<>>) ->
    case T:recv(S, 0, infinity) of
        {ok, Bytes} when byte_size(Bytes) > 0, byte_size(Bytes) =< ?CHUNK ->
            read_next(T, S, Mode, Bytes);
        {error, closed} when Mode =:= eof -> done;
        _ -> {error, unavailable}
    end;
read_next(_, _, eof, Bytes) -> {chunk, Bytes, eof, <<>>};
read_next(_, _, {length, N}, Bytes) ->
    Size = min(N, byte_size(Bytes)),
    <<Part:Size/binary, Rest/binary>> = Bytes,
    {chunk, Part, {length, N - Size}, Rest};
read_next(T, S, size, Buffer) ->
    case line(T, S, Buffer, <<>>, ?FRAME_LINE) of
        {ok, Line, Rest} ->
            [Hex | _] = binary:split(Line, <<";">>),
            %% Cap the digit count before conversion to avoid unbounded bignums.
            case byte_size(Hex) > 0 andalso byte_size(Hex) =< 16 andalso hex(Hex) of
                true ->
                    case binary_to_integer(Hex, 16) of
                        0 -> trailers(T, S, Rest, ?TRAILERS);
                        N -> read_next(T, S, {chunk, N}, Rest)
                    end;
                false -> {error, unavailable}
            end;
        Error -> Error
    end;
read_next(_, _, {chunk, N}, Bytes) ->
    Size = min(N, byte_size(Bytes)),
    <<Part:Size/binary, Rest/binary>> = Bytes,
    Mode = case N - Size of 0 -> cr; Left -> {chunk, Left} end,
    {chunk, Part, Mode, Rest};
read_next(T, S, cr, <<13, Rest/binary>>) -> read_next(T, S, lf, Rest);
read_next(T, S, lf, <<10, Rest/binary>>) -> read_next(T, S, size, Rest);
read_next(_, _, _, _) -> {error, unavailable}.

hex(<<>>) -> true;
hex(<<C, Rest/binary>>) when C >= $0, C =< $9; C >= $a, C =< $f; C >= $A, C =< $F -> hex(Rest);
hex(_) -> false.

%% Only framing lines accumulate, capped independently of payload. Consumed
%% socket slices are copied before the owner waits for the next read.
line(T, S, Buffer, Prefix, Limit) ->
    case binary:match(Buffer, <<"\r\n">>) of
        {At, 2} when byte_size(Prefix) + At =< Limit ->
            <<Part:At/binary, _:2/binary, Rest/binary>> = Buffer,
            {ok, <<Prefix/binary, Part/binary>>, Rest};
        nomatch when byte_size(Prefix) + byte_size(Buffer) =< Limit ->
            %% Retain the last byte so a split CRLF can be recognized.
            Combined = <<Prefix/binary, Buffer/binary>>,
            case T:recv(S, 0, infinity) of
                {ok, Bytes} when byte_size(Bytes) > 0, byte_size(Bytes) =< ?CHUNK ->
                    case Combined of
                        <<>> -> line(T, S, Bytes, <<>>, Limit);
                        _ ->
                            K = byte_size(Combined) - 1,
                            <<Keep:K/binary, Last>> = Combined,
                            line(T, S, <<Last, Bytes/binary>>, Keep, Limit)
                    end;
                _ -> {error, unavailable}
            end;
        _ -> {error, unavailable}
    end.

trailers(T, S, Buffer, Remaining) ->
    case line(T, S, Buffer, <<>>, min(?FRAME_LINE, Remaining)) of
        {ok, <<>>, _} -> done;
        {ok, Line, Rest} when byte_size(Line) + 2 =< Remaining ->
            case binary:match(Line, <<":">>) of
                nomatch -> {error, unavailable};
                _ -> trailers(T, S, Rest, Remaining - byte_size(Line) - 2)
            end;
        _ -> {error, unavailable}
    end.
