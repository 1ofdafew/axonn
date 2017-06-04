-module(konnect_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([start_link/1]).
-export([init/1]).

-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).
-define(CHILD(I, Type, Args), {I, {I, start_link, Args}, permanent, 5000, Type, [I]}).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_link(Module) ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, [Module]).


init([]) ->
  TcpPort = os:getenv(<<"AXONN_TCP_PORT">>, 18787),
  UdpPort = os:getenv(<<"AXONN_UDP_PORT">>, 18787),

  TCP = ?CHILD(tcp_sup, supervisor),
  UDP = ?CHILD(udp_svr, worker, [UdpPort, TcpPort]),

  Procs = [TCP, UDP],
  {ok, {{one_for_one, 60, 3600}, Procs}};

init([Module]) ->
  {ok, {{simple_one_for_one, 5, 60}, [
    {undefined, 
      {Module, start_link, []},
      temporary, 2000, worker, []}
  ]}}.

