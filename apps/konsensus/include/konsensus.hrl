-include("lager.hrl").

-record(request_vote, {
          term :: non_neg_integer(),
          candidate_id :: binary(),
          last_log_index :: non_neg_integer(),
          last_log_term :: non_neg_integer()
         }).
-type request_vote() :: #request_vote{}.


