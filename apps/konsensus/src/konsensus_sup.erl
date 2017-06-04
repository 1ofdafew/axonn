-module(konsensus_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).
-define(CHILD(I, Type, Args), {I, {I, start_link, Args}, permanent, 5000, Type, [I]}).
-define(CHILD(N, I, Type, Args), {N, {I, start_link, Args}, permanent, 5000, Type, [I]}).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  Trade = ?CHILD(trade_fsm, worker, ["Trade"]),
  Konsensus = ?CHILD(konsensus_fsm, worker),
  Dog = ?CHILD(dog_fsm, worker),

  Procs = [Trade, Konsensus, Dog],
  {ok, {{one_for_one, 5, 10}, Procs}}.

