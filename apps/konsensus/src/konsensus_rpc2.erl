-module(konsensus_rpc2).
-behaviour(gen_server).
-include("konsensus.hrl").

%% API.
-export([start_link/0]).
-export([send/2]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
          leader_id :: atom()
}).

-define(SERVER, ?MODULE).

%% API.

-spec start_link() -> {ok, pid()}.
start_link() ->
	gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

send(NodeId, Msg) ->
  gen_server:cast(?SERVER, {send, NodeId, Msg}).

%% gen_server.

init([]) ->
  ?INFO("Starting ~p...", [?MODULE]),
  process_flag(trap_exit, true),
	{ok, #state{}}.

handle_call(_Request, _From, State) ->
	{reply, ignored, State}.

handle_cast({send, NodeId, #request_vote{candidate_id=Candidate}=Msg}, State) ->
  ?INFO("~p :: sending heartbeat to ~p", [?MODULE, NodeId]),
  case konsensus_fsm:send_sync(NodeId, Msg) of
    Reply when is_record(Reply, vote) ->
      ?INFO("RPC :: Received vote reply: ~p, recipient: ~p", [Reply, Candidate]),
      Dest = konsensus_fsm:fsm_name(Candidate),
      konsensus_fsm:send(Dest, Reply),
      {noreply, State};
    Error ->
      ?ERROR("RPC :: Unable to send vote: ~p", [Error]),
      {noreply, State}
  end;
  
handle_cast({send, NodeId, #append_entries{leader_id=Leader}=Msg}, State) ->
  try
    konsensus_fsm:send(NodeId, Msg)
  catch
    _:Err ->
      ?ERROR("~p :: error in sending message to ~p: error = ~p", [?SERVER, NodeId, Err]),
      konsensus_fsm:inactive_member(Leader, NodeId)
  end,
  {noreply, State};

handle_cast(Msg, State) ->
  ?ERROR("~p :: received unknown cast: ~p", [?SERVER, Msg]),
	{noreply, State}.

handle_info(Info, State) ->
  ?INFO("~p :: received info: ~p", [?SERVER, Info]),
	{noreply, State}.

terminate(Reason, _State) ->
  ?INFO("~p :: received termination: reason = ~p", [?SERVER, Reason]),
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.
