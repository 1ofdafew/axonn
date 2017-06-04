-module(konsensus_fsm).
-behaviour(gen_fsm).

%% API.
-export([start/0]).
-export([start_link/0]).

%% gen_fsm.
-export([init/1]).
-export([idle/2]).
-export([state_name/2]).
-export([handle_event/3]).
-export([state_name/3]).
-export([handle_sync_event/4]).
-export([handle_info/3]).
-export([terminate/3]).
-export([code_change/4]).

-record(state, {
          uuid,   %% the uuid of the client
          role,   %% follower, candidate, leader
          term,   %% the term
          commit, %% the commit index
          log=[]  %% transaction log
}).

%% API.

start() ->
  gen_fsm:start(?MODULE, [], []).

-spec start_link() -> {ok, pid()}.
start_link() ->
	gen_fsm:start_link(?MODULE, [], []).

%% gen_fsm.

init([]) ->
	{ok, idle, #state{uuid=uuid()}}.

idle(wait_for_connection, StateData) ->
  {next_state, idle, StateData}.

state_name(_Event, StateData) ->
	{next_state, state_name, StateData}.

handle_event(_Event, StateName, StateData) ->
	{next_state, StateName, StateData}.

state_name(_Event, _From, StateData) ->
	{reply, ignored, state_name, StateData}.

handle_sync_event(_Event, _From, StateName, StateData) ->
	{reply, ignored, StateName, StateData}.

handle_info(_Info, StateName, StateData) ->
	{next_state, StateName, StateData}.

terminate(_Reason, _StateName, _StateData) ->
	ok.

code_change(_OldVsn, StateName, StateData, _Extra) ->
	{ok, StateName, StateData}.


%% ============================================================================
%%  Private functions
uuid() ->
  list_to_binary(uuid:uuid_to_string(uuid:get_v4())).

