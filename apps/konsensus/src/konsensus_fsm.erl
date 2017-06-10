-module(konsensus_fsm).
-behaviour(gen_fsm).

-include("konsensus.hrl").

%% API.
-export([start/1]).
-export([start_link/1]).
-export([start_link/3]).

-export([send/2]).
-export([send_sync/2]).
-export([get_leader/1]).
-export([join/2]).

%% gen_fsm.
-export([init/1]).
-export([handle_event/3]).
-export([handle_sync_event/4]).
-export([handle_info/3]).
-export([terminate/3]).
-export([code_change/4]).

%% fsm state callbacks
-export([follower/2]).
-export([follower/3]).
-export([candidate/2]).
-export([leader/2]).

-record(state, {
          leader        :: term(),   %% the current leader
          current_term  :: non_neg_integer(),
          voted_for     :: term(),
          timer         :: timer:tref(),
          self          :: binary(),
          members = []  :: [pid()],
          log_entry     :: konsensus_log:log_entry(),
          candidate     :: binary(),
          responses
}).

-define(SERVER, ?MODULE).

%% API.

-spec start(Name :: atom()) -> {ok, pid()}.
start(Name) ->
  gen_fsm:start({local, ?SERVER}, ?MODULE, Name, []).

-spec start_link(Name :: atom()) -> {ok, pid()}.
start_link(Name) ->
  gen_fsm:start_link(?MODULE, [Name], []).

-spec start_link(Actual :: atom(), Name :: atom(), Members :: list()) -> {ok, pid()}.
start_link(Actual, Name, Members) ->
  gen_fsm:start_link({local, Actual}, ?MODULE, [Name, Members], []).

send(To, Msg) ->
  gen_fsm:send_event(To, Msg).

send_sync(To, Msg) ->
  gen_fsm:sync_send_event(To, Msg, 100).

get_leader(Node) ->
  gen_fsm:sync_send_all_state_event(fsm_name(Node), get_leader).

join(Leader, Node) ->
  gen_fsm:sync_send_all_state_event(fsm_name(Leader), {join, Node}).

%% ============================================================================
%% gen_fsm.
%%
init(Name) ->
  [Id, Members] = Name,
  Timer = start_timer(),
  ?INFO("~p :: timer = ~p", [Id, Timer]),
  NewState = #state{timer=Timer, self=Id, current_term=0, members=Members},

  %% gen_fsm:send_all_state_event(self(), {join, Id}),
  %% Get the leader, and notify join
  case Members of 
    [] -> ok;
    [H|_]  ->
      %% pick one
      Leader = get_leader(H),
      join(Leader, Id)
  end,
  {ok, follower, NewState}.

%% handle_event({join, Id}, StateName, #state{members=Members} = StateData) ->
%%   ?INFO("~p :: received join info from ~p: members=~p", [Id, Id, Members]),
%%   UpdatedMembers = filter(Id, Members),
%%   {next_state, StateName, StateData#state{members=UpdatedMembers}};

handle_event(_Event, StateName, StateData) ->
  {next_state, StateName, StateData}.

handle_sync_event({join, Node}, _From, StateName, #state{self=Id, members=Members} = StateData) ->
  ?INFO("~p :: received join info from ~p: members=~p", [Id, Node, Members]),
  {reply, ok, StateName, StateData#state{members=[Node|Members]}};

handle_sync_event(get_leader, _From, StateName, #state{self=Id, leader=Leader} = StateData) ->
  ?INFO("~p :: current leader = ~p", [Id, Leader]),
  {reply, Leader, StateName, StateData};

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
follower(timeout, #state{members=Members} = State) ->
  case Members of
    [] ->
      NewState = assert_leadership(State),
      {next_state, leader, NewState};
    _ ->
      NewState = start_election(State),
      {next_state, candidate, NewState}
  end;

follower(#append_entries{leader_id=Leader, entries=[]},
         #state{self=Id, timer=Timer} = State) ->
  ?INFO("~p :: received heartbeat from ~p, timer=~p", [Id, Leader, Timer]),
  gen_fsm:cancel_timer(Timer),
  NewTimer = start_timer(),
  NewState = State#state{leader=Leader, timer=NewTimer},
  {next_state, follower, NewState};

follower(#append_entries{leader_id=Leader, term=Term, entries=Entries} = Msg,
         #state{self=Id, current_term=CurrentTerm} = State) ->
  ?INFO("~p :: received entries ~p from ~p -> ~p", [Id, Entries, Leader, Msg]),
  case Term < CurrentTerm of
    true ->
      %% lags behind.
      Response = #append_response{id=Id, term=Term, success=false},
      {reply, Response, follower, State};
    false ->
      %% konsensus_log:get_entry_at(1),
      Response = #append_response{id=Id, term=Term, success=false},
      {reply, Response, follower, State}
  end;

follower(Event, #state{self=Id} = State) ->
  unexpected(Event, follower, Id),
  {next_state, follower, State}.

follower(#request_vote{term=Term, candidate_id=CandidateId}, _From,
         #state{self=Self, current_term=CurrentTerm} = State) ->
  case Term > CurrentTerm of
    true ->
      Vote = #vote{term=CurrentTerm, vote_granted=true, id=Self},
      ?INFO("~p :: voting for ~p, #vote{}: ~p", [Self, CandidateId, Vote]),
      {reply, Vote, follower, State};
    false ->
      Vote = #vote{term=CurrentTerm, vote_granted=false, id=Self},
      ?INFO("~p :: not voting for ~p, #vote{}: ~p", [Self, CandidateId, Vote]),
      {reply, Vote, follower, State}
  end.

candidate(timeout, State) ->
  NewState = start_election(State),
  {next_state, candidate, NewState};

candidate(Event, #state{self=Id} = State) ->
  unexpected(Event, candidate, Id),
  {next_state, candidate, State}.

leader(timeout_heartbeat, State) ->
  NewTimer = send_heartbeat(State),
  {next_state, leader, State#state{timer=NewTimer}};

leader(Event, #state{self=Id} = State) ->
  unexpected(Event, leader, Id),
  {next_state, leader, State}.

%% ============================================================================
%% Synch State:
%%
%% state_name(_Event, _From, StateData) ->
%%   {reply, ignored, state_name, StateData}.

%% ============================================================================
%% State Logics
%%
start_election(#state{current_term=Term, self=Id} = State) ->
  ?INFO("~p :: Election timeout for term: ~p", [Id, Term]),
  Timer = start_timer(),
  R = dict:store(Id, true, dict:new()),
  NewState = State#state{timer=Timer, current_term=Term+1, leader=undefined, responses=R},
  ?INFO("~p :: requesting for votes", [Id]),
  request_votes(NewState),
  NewState.

request_votes(#state{current_term=Term, self=Id, members=Members}) ->
  LastLogIndex = konsensus_log:get_last_log_index(Id),
  LastLogTerm = konsensus_log:get_last_log_term(Id),
  VoteMsg = #request_vote{term=Term, candidate_id=Id, 
                          last_log_index=LastLogIndex,
                          last_log_term=LastLogTerm},
  ?INFO("~p :: #request_vote{}: ~p from members: ~p", [Id, VoteMsg, Members]),
  [ konsensus_rpc:send(fsm_name(N), VoteMsg) || N <- filter(Id, Members) ].

fsm_name(Id) ->
  N = atom_to_binary(Id, utf8),
  binary_to_atom(<<N/binary, "_fsm">>, utf8).

start_timer() ->
  gen_fsm:send_event_after(election_timeout(), timeout).

election_timeout() ->
  crypto:rand_uniform(5000, 7000).

heartbeat_timeout() ->
  crypto:rand_uniform(3000, 5000).

assert_leadership(#state{self=Id} = State) ->
  NewTimer = send_heartbeat(State),
  State#state{responses=dict:new(), leader=Id, timer=NewTimer}.

send_heartbeat(#state{self=Id, members=Members, current_term=CurrentTerm, timer=Timer} = State) ->
  gen_fsm:cancel_timer(Timer),
  case Members of
    [] ->
      ok;
    _ ->
      ?INFO("~p :: Sending heartbeat to members ~p", [Id, Members]),
      ?DEBUG("~p #state{}: ~p", [Id, State]),

      %% get the log entries
      %% ...
      LastLogIndex = konsensus_log:get_last_log_index(Id),
      LastLogTerm = konsensus_log:get_last_log_term(Id),
      CommitIndex = konsensus_log:get_commit_index(Id),
      Msg = #append_entries{
               term=CurrentTerm,
               leader_id=Id,
               prev_log_index=LastLogIndex,
               prev_log_term=LastLogTerm,
               entries=[],
               commit_index=CommitIndex},
      ?INFO("~p :: #append_entries{}: ~p, members=~p", [Id, Msg, filter(Id, Members)]),
      [ konsensus_rpc:send(fsm_name(N), Msg) || N <- filter(Id, Members) ]
  end,
  gen_fsm:send_event_after(heartbeat_timeout(), timeout_heartbeat).

%% ============================================================================
%%  Private functions
%%
%% uuid() ->
%%   list_to_binary(uuid:uuid_to_string(uuid:get_v4())).

filter(Id, Members) ->
  lists:filter(fun(X) -> 
                   case X =:= Id of 
                     true -> false; 
                     false -> true 
                   end 
               end, Members).


unexpected(Msg, State, Id) ->
  ?ERROR("~p :: unknown message ~p while in state ~p", [Id, Msg, State]).

