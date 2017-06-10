-module(konsensus_fsm).
-behaviour(gen_fsm).

-include("konsensus.hrl").

%% API.
-export([start/1]).
-export([start_link/0]).

%% gen_fsm.
-export([init/1]).
-export([handle_event/3]).
-export([handle_sync_event/4]).
-export([handle_info/3]).
-export([terminate/3]).
-export([code_change/4]).

%% fsm state callbacks
-export([follower/2]).
-export([candidate/2]).

-record(state, {
          leader :: term(),   %% the current leader
          curr_term, 
          voted_for :: term(),
          timer :: timer:tref(),

          self :: term(),
          members = [] :: [pid()],
          log_entry,
          candidate,
          responses
}).

-define(SERVER, ?MODULE).

%% API.

start(Members) ->
  gen_fsm:start({local, ?SERVER}, ?MODULE, Members, []).

-spec start_link() -> {ok, pid()}.
start_link() ->
  gen_fsm:start_link({local, ?SERVER}, ?MODULE, [], []).

%% gen_fsm.

init(Members) ->
  Timer = reset_timer(),
  NewState = #state{timer=Timer, self=uuid(), curr_term=0, members=Members},
  {ok, follower, NewState}.

handle_event(_Event, StateName, StateData) ->
  {next_state, StateName, StateData}.

handle_sync_event(_Event, _From, StateName, StateData) ->
  {reply, ignored, StateName, StateData}.

handle_info(_Info, StateName, StateData) ->
  {next_state, StateName, StateData}.

terminate(_Reason, _StateName, _StateData) ->
  ok.

code_change(_OldVsn, StateName, StateData, _Extra) ->
  {ok, StateName, StateData}.

%% ============================================================================
%% Async State: follower, candidate, leader
%%
follower(timeout, State) ->
  NewState = start_election(State),
  {next_state, candidate, NewState}.

candidate(timeout, State) ->
  NewState = start_election(State),
  {next_state, candidate, NewState}.

%% ============================================================================
%% Synch State:
%%
%% state_name(_Event, _From, StateData) ->
%%   {reply, ignored, state_name, StateData}.

%% ============================================================================
%% State Logics

start_election(State = #state{curr_term=Term, self=Id}) ->
  ?INFO("Election timeout for ~p: ~p~n", [Id, Term]),
  Timer = reset_timer(),
  R = dict:store(Id, true, dict:new()),
  NewState = State#state{timer=Timer, curr_term=Term+1, leader=undefined, responses=R},
  ?INFO("~p requesting for votes~n", [Id]),
  request_votes(NewState),
  NewState.

request_votes(#state{curr_term=Term, self=Id, members=Members}) ->
  LastIndex = 1,
  LastTerm = 1,
  VoteMsg = #request_vote{term=Term, candidate_id=Id, last_log_index=LastIndex,
                          last_log_term=LastTerm},
  ?INFO("~p #request_vote{}: ~p from members: ~p~n", [Id, VoteMsg, Members]),
  [ konsensus_rpc:send(fsm_name(N), VoteMsg) || N <- filter(Id, Members) ].

fsm_name(Id) ->
  <<Id/binary, "_fsm">>.

reset_timer() ->
  gen_fsm:send_event_after(election_timeout(), timeout).

election_timeout() ->
  crypto:rand_uniform(1500, 3000).

%% ============================================================================
%%  Private functions
uuid() ->
  list_to_binary(uuid:uuid_to_string(uuid:get_v4())).

filter(Id, Members) ->
  lists:filter(fun(X) -> 
                   case X =:= Id of 
                     true -> true; 
                     false -> false 
                   end 
               end, Members).


