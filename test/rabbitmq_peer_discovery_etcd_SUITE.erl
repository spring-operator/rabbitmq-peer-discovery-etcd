%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License at
%% http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%% License for the specific language governing rights and limitations
%% under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is AWeber Communications.
%% Copyright (c) 2015-2016 AWeber Communications
%% Copyright (c) 2016-2017 Pivotal Software, Inc. All rights reserved.
%%

-module(rabbitmq_peer_discovery_etcd_SUITE).

-compile(export_all).
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").


all() ->
    [
     {group, unit}
    ].

groups() ->
    [
     {unit, [], [
                 extract_nodes_test
                 , base_path_defaults_test
                 , nodes_path_defaults_test
                 , list_nodes_without_existing_directory_test
                ]}
    ].


reset() ->
    meck:unload(),
    application:unset_env(rabbit, cluster_formation),
    [os:unsetenv(Var) || Var <- [
                                 "CLUSTER_NAME",
                                 "ETCD_SCHEME",
                                 "ETCD_HOST",
                                 "ETCD_PORT",
                                 "ETCD_PREFIX",
                                 "ETCD_NODE_TTL",
                                 "LOCK_WAIT_TIME"
                                ]].

init_per_testcase(_TC, Config) ->
    reset(),
    meck:new(rabbit_log, []),
    Config.

end_per_testcase(_TC, Config) ->
    reset(),
    Config.



%%
%% Test cases
%%

extract_nodes_test(_Config) ->
    Values = #{<<"action">> => <<"get">>,
               <<"node">> => #{<<"createdIndex">> => 4,
                               <<"dir">> => true,
                               <<"key">> => <<"/rabbitmq/default/nodes">>,
                               <<"modifiedIndex">> => 4,
                               <<"nodes">> => [#{<<"createdIndex">> => 4,
                                                 <<"expiration">> => <<"2017-06-06T13:24:49.430945264Z">>,
                                                 <<"key">> => <<"/rabbitmq/default/nodes/rabbit@172.17.0.7">>,
                                                 <<"modifiedIndex">> => 4,
                                                 <<"ttl">> => 24,
                                                 <<"value">> => <<"enabled">>},
                                               #{<<"createdIndex">> => 7,
                                                 <<"expiration">> => <<"2017-06-06T13:24:51.846531249Z">>,
                                                 <<"key">> => <<"/rabbitmq/default/nodes/rabbit@172.17.0.5">>,
                                                 <<"modifiedIndex">> => 7,
                                                 <<"ttl">> => 26,
                                                 <<"value">> => <<"enabled">>}]}},
    Expectation = ['rabbit@172.17.0.7', 'rabbit@172.17.0.5'],
  ?assertEqual(Expectation, rabbit_peer_discovery_etcd:extract_nodes(Values)).


base_path_defaults_test(_Config) ->
  ?assertEqual([v2, keys, "rabbitmq", "default"],
               rabbit_peer_discovery_etcd:base_path(#{})).


nodes_path_defaults_test(_Config) ->
  ?assertEqual([v2, keys, "rabbitmq", "default", nodes, rabbit_data_coercion:to_list(node())],
               rabbit_peer_discovery_etcd:node_path(#{})).


list_nodes_without_existing_directory_test(_Config) ->
    meck:new(rabbit_peer_discovery_httpc, [passthrough]),
    EtcdNodesResponse = [{<<"action">>, <<"get">>},
                               {<<"node">>,
                                   [{<<"key">>, <<"/rabbitmq/default">>},
                                         {<<"dir">>, true},
                                         {<<"nodes">>,
                                          [[{<<"key">>, <<"/rabbitmq/default/autocluster-etcd-4">>},
                                                    {<<"value">>, <<"enabled">>},
                                                    {<<"expiration">>, <<"2016-07-04T12:47:17.245647965Z">>},
                                                    {<<"ttl">>, 23},
                                                    {<<"modifiedIndex">>, 3976},
                                                    {<<"createdIndex">>, 3976}]]}]}],
    meck:sequence(rabbit_peer_discovery_httpc, get, 5, [{error, "404"}, EtcdNodesResponse]),
    meck:expect(rabbit_peer_discovery_httpc, put, fun (_, _, _, _, _, _) -> {ok, ok} end),
    rabbit_peer_discovery_etcd:list_nodes(),
    ?assert(meck:validate(rabbit_peer_discovery_httpc)).