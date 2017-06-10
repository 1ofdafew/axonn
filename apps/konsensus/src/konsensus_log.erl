-module(konsensus_log).
-behaviour(gen_server).
-include("konsensus.hrl").

%% API.
-export([start_link/1]).
-export([get_last_log_index/1]).
-export([get_last_log_term/1]).
-export([get_commit_index/1]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
          id              :: binary(),
          dict            :: ordict:orddict(),
          last_log_entry  :: konsensus_log:log_entry(),
          index=0         :: non_neg_integer(),
          term=0          :: non_neg_integer(),
          commit_index=0  :: non_neg_integer()
}).

%% ============================================================================
%% API.
%%
-spec start_link(Name :: atom()) -> {ok, pid()}.
start_link(Name) ->
	gen_server:start_link({local, Name}, ?MODULE, [Name], []).

get_last_log_index(Node) ->
  gen_server:call(Node, last_log_index).

get_last_log_term(Node) ->
  gen_server:call(Node, last_log_term).

get_commit_index(Node) ->
  gen_server:call(Node, commit_index).

%% ============================================================================
%% gen_server.
%%
init([Name]) ->
  ?INFO("Starting ~p~n", [Name]),
	{ok, #state{id=Name, dict=orddict:new()}}.

handle_call(last_log_index, _From, State = #state{index=Index}) ->
  {reply, Index, State};

handle_call(last_log_term, _From, State = #state{term=Term}) ->
  {reply, Term, State};

handle_call(commit_index, _From, State = #state{commit_index=CommitIndex}) ->
  {reply, CommitIndex, State};

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

%% ============================================================================
%% Internal functions
%%
%% log_name(Name) ->
%%   N = atom_to_binary(Name, utf8),
%%   binary_to_atom(<<N/binary, "_log">>, utf8).

