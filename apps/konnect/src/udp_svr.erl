-module(udp_svr).
-behaviour(gen_server).

%% API.
-export([start/0]).
-export([start_link/2]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
          mode, 
          port,
          tcp,
          sock
}).

%% API.
-spec start() -> {ok, pid()}.
start() ->
	gen_server:start(?MODULE, [], []).

-spec start_link(UDPPort :: integer(), TCPPort :: integer()) -> {ok, pid()}.
start_link(UDPPort, TCPPort) ->
	gen_server:start_link(?MODULE, [UDPPort, TCPPort], []).

%% gen_server.

init([]) ->
  Options = [
             binary, 
             {active, true}, 
             {broadcast, true}
            ],
  {ok, Sock} = gen_udp:open(0, Options),
  Msg = {init, discover},
  io:format("Sending init message...~n", []),
  gen_udp:send(Sock, {255,255,255,255}, 18787, bert:encode(Msg)),
  {ok, #state{sock=Sock}};
 
init([UDPPort, TCPPort]) ->
  Options = [
             binary, 
             {active, true}, 
             {broadcast, true}
            ],
  {ok, Sock} = gen_udp:open(UDPPort, Options),
  io:format("~p: starting UDP port at ~p~n", [?MODULE, UDPPort]),
	{ok, #state{mode=server, port=UDPPort, tcp=TCPPort, sock=Sock}}.

handle_call(Request, _From, State) ->
  io:format("Received Request: ~p~n", [Request]),
	{reply, ignored, State}.

handle_cast(Msg, State) ->
  io:format("Received Cast: ~p~n", [Msg]),
	{noreply, State}.

handle_info({udp, ClientSock, ClientIP, ClientPort, Payload}, 
            #state{sock=Sock, tcp=Tcp}=State) ->
  %%
  %% the state tables
  %%  
  %%  +------+    +--------------+    +------------+
  %%  | init | -> | get IP, Port | -> | disconnect |
  %%  +------+    +--------------+    +------------+
  %%
  case bert:decode(Payload) of
    {init, discover} ->
      {ok, [{MyIP, _, _}, _]} = inet:getif(),
      Msg = [{ip, MyIP}, {port, Tcp}],
      io:format("Sending back response: ~p~n", [Msg]),
      gen_udp:send(Sock, ClientIP, ClientPort, bert:encode(Msg)),
	    {noreply, State};
    [{ip, PayIP}, {port, PayPort}] ->
      %% call the TCP server with this info for subsequent data transfer
      io:format("Calling ~p at TCP port ~p~n", [PayIP, PayPort]),
      tcp_client:start_link(PayIP, PayPort),
      Msg = {close, tq},
      gen_udp:send(Sock, ClientIP, ClientPort, bert:encode(Msg)),
	    {noreply, State};
    {close, tq} ->
      io:format("Synchronising data with ~p on TCP protocol ~n", [ClientIP]),
      gen_udp:close(ClientSock),
      {noreply, State};
    Else ->
      io:format("Unknown packet: ~p~n", [Else]),
	    {noreply, State}
  end;

handle_info(Info, State) ->
  io:format("Received Info: ~p~n", [Info]),
	{noreply, State}.

terminate(Reason, _State) ->
  io:format("Terminate Reason: ~p~n", [Reason]),
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

