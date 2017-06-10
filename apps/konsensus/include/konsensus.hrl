-include("lager.hrl").

-record(request_vote, {
          term            :: non_neg_integer(),
          candidate_id    :: binary(),
          last_log_index  :: non_neg_integer(),
          last_log_term   :: non_neg_integer()
         }).
-type request_vote() :: #request_vote{}.

-record(vote, {
          id              :: atom(),
          term            :: non_neg_integer(),
          vote_granted    :: boolean()
         }).
-type vote() :: #vote{}.

-record(log_entry, {
          index           :: non_neg_integer(),
          term            :: non_neg_integer(),
          command         :: atom()
         }).
-type log_entry()   :: #log_entry{}.
-type log_entries() :: [log_entry()].

-record(append_entries, {
          term            :: non_neg_integer(),
          leader_id       :: atom(),
          prev_log_index  :: non_neg_integer(),
          prev_log_term   :: non_neg_integer(),
          entries = []    :: list(),
          commit_index    :: non_neg_integer()
         }).
-type append_entries() :: #append_entries{}.

-record(append_response, {
          id              :: atom(),
          term            :: non_neg_integer(),
          success         :: boolean()
         }).
-type append_response() :: #append_response{}.

