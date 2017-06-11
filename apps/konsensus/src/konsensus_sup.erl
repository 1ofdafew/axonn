-module(konsensus_sup).
-behaviour(supervisor).
-include("konsensus.hrl").

%% API Exports
-export([start_link/0]).
-export([init/1]).
-export([start_node/2]).
-export([stop_node/1]).

-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).
-define(CHILD(I, Args, Type), {I, {I, start_link, Args}, permanent, 5000, Type, [I]}).
-define(CHILD(N, I, Args, Type), {N, {I, start_link, Args}, permanent, 5000, Type, [I]}).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  %% Trade = ?CHILD(trade_fsm, worker, ["Trade"]),
  %% Konsensus = ?CHILD(konsensus_fsm, worker),
  %% Log = ?CHILD(konsensus_log, worker, 
  %% Dog = ?CHILD(dog_fsm, worker),
  RPC = ?CHILD(konsensus_rpc2, worker),

  Procs = [RPC],
  {ok, {{one_for_one, 5, 10}, Procs}}.

-spec start_node(Name :: atom(), Members :: list()) -> {ok | term()}.
start_node(Name, Members) ->
  SupervisorName = generate_name(Name),
  start_child(SupervisorName, Name, Members).

-spec stop_node(Name :: atom()) -> {ok | term()}.
stop_node(Name) ->
  SupervisorName = generate_name(Name),
  case supervisor:terminate_child(?MODULE, SupervisorName) of
    ok ->
      supervisor:delete_child(?MODULE, SupervisorName);
    {error, _} ->
      ?ERROR("Can't find ~p~n", [Name])
  end.


%% ============================================================================
%% Private functions
%%
start_child(SupervisorName, Name, Members) ->
  ?INFO("Starting child [~p, ~p, ~p]", [SupervisorName, Name, Members]),
  Sup = ?CHILD(SupervisorName, konsensus_node_sup, [Name, Members], supervisor),
  supervisor:start_child(?MODULE, Sup).

generate_name(Name) ->
  SupName = atom_to_binary(Name, utf8),
  binary_to_atom(<<SupName/binary, "_konsensus_node_sup">>, utf8).

