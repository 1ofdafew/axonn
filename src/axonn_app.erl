-module(axonn_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
  Resp = axonn_sup:start_link(),

  %% prepare our node members
  Leader = uuid(),
  konsensus_sup:start_node(Leader, []),
  timer:sleep(1000),

  lists:foreach( 
    fun(N) -> 
        konsensus_sup:start_node(N, [Leader])
    end,
    [ uuid() || _X <- lists:seq(1,5) ]), 

  %% return the start_link response above
  Resp.

stop(_State) ->
  ok.

uuid() ->
  Node = base58:binary_to_base58(crypto:strong_rand_bytes(5)),
  list_to_atom(Node).
  %% konsensus_fsm:uuid().
