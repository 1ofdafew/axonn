-module(tcp_listener).
-behaviour(gen_server).

%% API.
-export([start_link/2]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
          listener,
          acceptor,
          module
}).

%% API.

start_link(Port, Module) ->
	gen_server:start_link(?MODULE, [Port, Module], []).

%% gen_server.

init([Port, Module]) ->
  Opts = [binary, {packet, 2}, {reuseaddr, true}, 
          {keepalive, true}, {backlog, 30}, {active, false}],
  case gen_tcp:listen(Port, Opts) of
    {ok, ListenSocket} ->
        %%Create first accepting process
        {ok, Ref} = prim_inet:async_accept(ListenSocket, -1),
        {ok, #state{listener = ListenSocket,
                    acceptor = Ref,
                    module   = Module}};
    {error, Reason} ->
        {stop, Reason}
  end.

handle_call(_Request, _From, State) ->
	{reply, ignored, State}.

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.
