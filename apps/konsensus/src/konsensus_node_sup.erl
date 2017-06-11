-module(konsensus_node_sup).
-behaviour(supervisor).
-include("konsensus.hrl").

-export([start_link/2]).
-export([init/1]).

-spec start_link(Name :: atom(), Members :: list()) -> {ok | term() }.
start_link(Name, Members) ->
  SupName = atom_to_binary(Name, utf8),
  SupervisorName = binary_to_atom(<<SupName/binary, "_sup">>, utf8),
  start_link(Name, SupervisorName, Name, Members).

start_link(Proc, SupName, Name, Members) ->
	supervisor:start_link({local, SupName}, ?MODULE, [Proc, Name, Members]).

init([Proc, Name, Members]) ->
  ?DEBUG("Starting node_sup for [~p, ~p, ~p]", [Proc, Name, Members]),
  %% the storage log
  LogName = proc_name(Proc, <<"_log">>),
  Log = {LogName, 
         {konsensus_log, start_link, [Proc]},
         permanent, 5000, worker, [konsensus_log]},

  %% start the FSM module
  FSMName = proc_name(Proc, <<"_fsm">>),
  FSM = {FSMName,
         {konsensus_fsm, start_link, [FSMName, Name, Members]},
         permanent, 5000, worker, [konsensus_fsm]},

	Procs = [Log, FSM],
  ?DEBUG("Starting processes [~p]", [Procs]),
	{ok, {{one_for_all, 1, 5}, Procs}}.

-spec proc_name(Name :: atom(), Extra :: binary()) -> atom().
proc_name(Name, Extra) ->
  N = atom_to_binary(Name, utf8),
  binary_to_atom(<<N/binary, Extra/binary>>, utf8).

