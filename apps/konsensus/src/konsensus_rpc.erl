-module(konsensus_rpc).
-include("konsensus.hrl").

-export([send/2]).

send(NodeId, #request_vote{candidate_id=From}=Msg) ->
  spawn(fun() ->
            case konsensus_fsm:send_sync(NodeId, Msg) of
              Reply when is_record(Reply, vote) ->
                konsensus_fsm:send(From, Reply);
              Error ->
                ?ERROR("Unable to send vote: ~p~n", [Error])
            end
        end).

