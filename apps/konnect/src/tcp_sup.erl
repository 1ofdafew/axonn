-module(tcp_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  Port = os:getenv(<<"AXONN_TCP_PORT">>, 8787),
  {ok, Sock} = gen_tcp:listen(Port, [binary, {active, once}]),
  spawn_link(fun spawn_listeners/0),

  Server = {server,
            {tcp_svr, start_link, [Sock]},
            temporary, 1000, worker, [tcp_svr]},
  Procs = [Server],
  {ok, {{simple_one_for_one, 60, 3600}, Procs}}.

start_socket() ->
  supervisor:start_child(?MODULE, []).

spawn_listeners() ->
  [start_socket() || _ <- lists:seq(1, 10)],
  ok.

