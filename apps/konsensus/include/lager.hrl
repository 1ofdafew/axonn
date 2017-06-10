
-define(DEBUG(Text), lager:log(debug, ?MODULE, "~p:~p: " ++ Text ++ "~n", [?MODULE, ?LINE])).
-define(DEBUG(Text, Args), lager:log(debug, ?MODULE, "~p:~p: " ++ Text ++ "~n", [?MODULE, ?LINE | Args])).

-define(INFO(Text), lager:log(info, ?MODULE, "~p:~p: " ++ Text ++ "~n", [?MODULE, ?LINE])).
-define(INFO(Text, Args), lager:log(info, ?MODULE, "~p:~p: " ++ Text ++ "~n", [?MODULE, ?LINE | Args])).

-define(WARN(Text), lager:log(warning, ?MODULE, "~p:~p: " ++ Text ++ "~n", [?MODULE, ?LINE])).
-define(WARN(Text, Args), lager:log(warning, ?MODULE, "~p:~p: " ++ Text ++ "~n", [?MODULE, ?LINE | Args])).

-define(ERROR(Text), lager:log(error, ?MODULE, "~p:~p: " ++ Text ++ "~n", [?MODULE, ?LINE])).
-define(ERROR(Text, Args), lager:log(error, ?MODULE, "~p:~p: " ++ Text ++ "~n", [?MODULE, ?LINE | Args])).

