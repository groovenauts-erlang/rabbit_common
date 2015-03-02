%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2014 GoPivotal, Inc.  All rights reserved.
%%

-record(user, {username :: binary(),
               tags :: list(),
               auth_backend :: atom(), %% Module this user came from
               impl :: term()          %% Scratch space for that module
              }).

-record(internal_user, {username :: binary(), password_hash :: binary(), tags :: list()}).
-record(permission, {configure :: term(), write :: boolean(), read :: boolean()}).
-record(user_vhost, {username :: binary(), virtual_host :: binary()}).
-record(user_permission, {user_vhost :: binary(), permission :: #permission{} }).

-record(vhost, {virtual_host :: binary(), dummy :: term()}).

-record(content,
        {class_id :: term(),
         properties :: term(), %% either 'none', or a decoded record/tuple
         properties_bin :: binary(), %% either 'none', or an encoded properties binary
         %% Note: at most one of properties and properties_bin can be
         %% 'none' at once.
         protocol :: binary(), %% The protocol under which properties_bin was encoded
         payload_fragments_rev :: list() %% list of binaries, in reverse order (!)
         }).

-record(resource, {virtual_host :: binary(), kind :: atom(), name :: binary()}).

%% fields described as 'transient' here are cleared when writing to
%% rabbit_durable_<thing>
-record(exchange, {
          name :: binary(), type :: atom(), durable :: boolean(), auto_delete :: boolean(),
          internal :: boolean(), arguments :: list(), %% immutable
          scratches :: list(),    %% durable, explicitly updated via update_scratch/3
          policy :: term(),       %% durable, implicitly updated when policy changes
          decorators :: term()}). %% transient, recalculated in store/1 (i.e. recovery)

-record(amqqueue, {
          name :: binary(), durable :: boolean(), auto_delete :: boolean(),
          exclusive_owner = none :: atom(), %% immutable
          arguments :: list(),                   %% immutable
          pid :: pid(),                         %% durable (just so we know home node)
          slave_pids :: list(), sync_slave_pids :: list(), %% transient
          down_slave_nodes :: list(),            %% durable
          policy :: term(),                      %% durable, implicit update as above
          gm_pids :: list(),                     %% transient
          decorators :: list(),                  %% transient, recalculated as above
          state :: term()}).                     %% durable (have we crashed?)

-record(exchange_serial, {name :: binary(), next :: term() }).

%% mnesia doesn't like unary records, so we add a dummy 'value' field
-record(route, {binding :: binary(), value = const :: atom()}).
-record(reverse_route, {reverse_binding :: binary(), value = const :: atom()}).

-record(binding, {source :: binary(), key :: binary(), destination :: binary(), args = [] :: list()}).
-record(reverse_binding, {destination :: binary(), key :: binary(), source :: binary(), args = []}).

-record(topic_trie_node, {trie_node :: term(), edge_count :: integer(), binding_count :: integer()}).
-record(topic_trie_edge, {trie_edge :: term(), node_id :: term()}).
-record(topic_trie_binding, {trie_binding :: term(), value = const :: atom()}).

-record(trie_node, {exchange_name :: binary(), node_id :: term()}).
-record(trie_edge, {exchange_name :: binary(), node_id :: term(), word :: term()}).
-record(trie_binding, {exchange_name :: binary(), node_id :: term(), destination :: binary(), arguments :: list()}).

-record(listener, {node :: binary(), protocol :: binary(), host :: binary(), ip_address :: term(), port :: integer()}).

-record(runtime_parameters, {key :: term(), value :: term()}).

-record(basic_message, {exchange_name :: binary(), routing_keys = [] :: list(),
                        content :: binary(), id :: term(), is_persistent :: boolean()}).

-record(ssl_socket, {tcp :: term(), ssl :: term()}).
-record(delivery, {mandatory :: term(), confirm :: term(), sender :: term(), message :: term(), msg_seq_no :: term()}).
-record(amqp_error, {name :: term(), explanation = "" :: string(), method = none :: atom()}).

-record(event, {type :: atom(), props :: term(), reference = undefined :: term(), timestamp :: term()}).

-record(message_properties, {expiry :: term(), needs_confirming = false :: boolean(), size :: integer()}).

-record(plugin, {name :: atom(),                       %% atom()
                 version :: string(),                  %% string()
                 description :: string(),              %% string()
                 type :: atom(),                       %% 'ez' or 'dir'
                 dependencies :: [{atom(), string()}], %% [{atom(), string()}]
                 location :: string()}).               %% string()

%%----------------------------------------------------------------------------

-define(COPYRIGHT_MESSAGE, "Copyright (C) 2007-2014 GoPivotal, Inc.").
-define(INFORMATION_MESSAGE, "Licensed under the MPL.  See http://www.rabbitmq.com/").
-define(ERTS_MINIMUM, "5.6.3").

%% EMPTY_FRAME_SIZE, 8 = 1 + 2 + 4 + 1
%%  - 1 byte of frame type
%%  - 2 bytes of channel number
%%  - 4 bytes of frame payload length
%%  - 1 byte of payload trailer FRAME_END byte
%% See rabbit_binary_generator:check_empty_frame_size/0, an assertion
%% called at startup.
-define(EMPTY_FRAME_SIZE, 8).

-define(MAX_WAIT, 16#ffffffff).

-define(HIBERNATE_AFTER_MIN,        1000).
-define(DESIRED_HIBERNATE,         10000).
-define(CREDIT_DISC_BOUND,   {2000, 500}).

-define(INVALID_HEADERS_KEY, <<"x-invalid-headers">>).
-define(ROUTING_HEADERS, [<<"CC">>, <<"BCC">>]).
-define(DELETED_HEADER, <<"BCC">>).

%% Trying to send a term across a cluster larger than 2^31 bytes will
%% cause the VM to exit with "Absurdly large distribution output data
%% buffer". So we limit the max message size to 2^31 - 10^6 bytes (1MB
%% to allow plenty of leeway for the #basic_message{} and #content{}
%% wrapping the message body).
-define(MAX_MSG_SIZE, 2147383648).

%% First number is maximum size in bytes before we start to
%% truncate. The following 4-tuple is:
%%
%% 1) Maximum size of printable lists and binaries.
%% 2) Maximum size of any structural term.
%% 3) Amount to decrease 1) every time we descend while truncating.
%% 4) Amount to decrease 2) every time we descend while truncating.
%%
%% Whole thing feeds into truncate:log_event/2.
-define(LOG_TRUNC, {100000, {2000, 100, 50, 5}}).

-define(store_proc_name(N), rabbit_misc:store_proc_name(?MODULE, N)).
