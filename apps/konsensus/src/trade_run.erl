-module(trade_run).
-compile(export_all).

start() ->
	S = self(),
	CarlParent = spawn(fun() -> carl(S) end),
	receive
		Carl -> 
			spawn(fun() -> jim(Carl, CarlParent) end)
	end.

carl(Parent) ->
	{ok, Pid} = trade_fsm:start_link("Carl"),
	Parent ! Pid,
	io:format("spawned Carl: ~p~n", [Pid]),
	timer:sleep(800),

	% accept trade
	trade_fsm:accept_trade(Pid),
	timer:sleep(400),
	io:format("Trade ready?: ~p~n", [trade_fsm:ready(Pid)]),
	timer:sleep(1000),

	% make offer
	trade_fsm:make_offer(Pid, "horse"),
	trade_fsm:make_offer(Pid, "sword"),
	timer:sleep(1000),
	sync2(),

	% ready again
	trade_fsm:ready(Pid),
	timer:sleep(200),
	trade_fsm:ready(Pid),
	timer:sleep(1000).

jim(Jim, Parent) ->
	{ok, Pid} = trade_fsm:start_link("Jim"),
	io:format("spawned Jim: ~p~n", [Pid]),
	timer:sleep(500),
	trade_fsm:trade(Pid, Jim),

	% make offers
	trade_fsm:make_offer(Pid, "boots"),
	timer:sleep(200),
	trade_fsm:retract_offer(Pid, "boots"),
	timer:sleep(500),
	trade_fsm:make_offer(Pid, "shotgun"),
	timer:sleep(1000),
	sync1(Parent),

	% trade
	trade_fsm:make_offer(Pid, "horse"), %% already offered!
	trade_fsm:ready(Pid),
	timer:sleep(200),
	timer:sleep(1000).

sync1(Pid) ->
	Pid ! self(),
	receive
		ack -> ok
	end.

sync2() ->
	receive
		From -> From ! ack
	end.

