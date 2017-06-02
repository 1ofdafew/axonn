PROJECT = axonn
PROJECT_DESCRIPTION = New project
PROJECT_VERSION = 0.1.0

# Whitespace to be used when creating files from templates.
SP = 2
EUNIT_OPTS = verbose
EUNIT_ERL_OPTS = -args_file rel/vm.args -config rel/sys.config

DEPS = lager sync
LOCAL_DEPS = krypto mnesia crypto public_key inets sasl


include erlang.mk
