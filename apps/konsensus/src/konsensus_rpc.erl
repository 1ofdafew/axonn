-module(konsensus_rpc).
-include("konsensus.hrl").

-export([send/2]).

send(NodeId, #request_vote{candidate_id=Candidate}=Msg) ->
  Pid = spawn_link(
          fun() -> 
            try 
              case konsensus_fsm:send_sync(NodeId, Msg) of
                Reply when is_record(Reply, vote) ->
                  ?INFO("RPC :: Received vote reply: ~p, recipient: ~p", [Reply, Candidate]),
                  Dest = konsensus_fsm:fsm_name(Candidate),
                  konsensus_fsm:send(Dest, Reply);
                Error ->
                  ?ERROR("RPC :: Unable to send vote: ~p", [Error])
              end
            catch 
              _:Err ->
                ?ERROR("RPC :: unable to send to client: ~p", [Err]),
                error
            end 
          end),
  register(fsm_send, Pid),
  receive
    R -> R
  end;

send(NodeId, Msg) ->
  spawn(fun() ->
            konsensus_fsm:send(NodeId, Msg)
        end).
