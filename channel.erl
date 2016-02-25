-module(channel).
-export([loop/1, handle/2, initial_state/2]).
-include_lib("./defs.hrl").

%% Produce initial state
initial_state(Atom, Name) ->
    #channel_state {
       atom = Atom,
       name = Name
      }.

%% -----------------------------------------------------------------------------

%% handle/2 handles requests from a server

%% All requests are processed by handle/2 receiving the request data (and the
%% current state), performing the needed actions, and returning a tuple
%% {reply, Reply, NewState}, where Reply is the reply to be sent to the
%% requesting process and NewState is the new state of the client.

loop(State) ->
    receive 
         Request ->
            NewState = handle(State, Request),
            loop(NewState)
    end.

%% Join channel. Allows same user to join multiple times, and thus assumes that
%% if the user can only join once, the client keeps track of this.
%% Parameters in request:
%%   User: A user record for the joining user
handle(State, {join, User}) ->
    NewState = State#channel_state{ users = [User | State#channel_state.users] },
    NewState;

%% Leave channel. If user is not in channel this has no effect.
%% Parameters in request:
%%   User: A user record for the leaving user
handle(State, {leave, User}) ->
    NewState = State#channel_state{ users = lists:delete(User, State#channel_state.users) },
    NewState;

%% Send message
%% Parameters in request:
%%   Sender: A user record for the sending user
%%   Message: A string containing the message to send
handle(State, {send_message, Sender, Message}) ->
    UsersToSendTo = lists:filter(fun(User) -> Sender#user.pid =/= User#user.pid
                                 end, State#channel_state.users),
    lists:foreach(fun(Receiver) -> send_message(State, Sender, Receiver,
                                                Message) end, UsersToSendTo),
    State.

%% -----------------------------------------------------------------------------

%% Parameters:
%%   Sender: A user record for the sending user
%%   Receiver: A user record for the user that should receive the message
%%   Message: A string containing the message
send_message(State, Sender, Receiver, Message) ->
    spawn(fun() -> genserver:request(Receiver#user.pid, {incoming_msg, State#channel_state.name, Sender#user.nick, Message}) end).

%% -----------------------------------------------------------------------------

%% Parameters:
%%   User: A user record for the user that we want to check for
is_user_in_channel(State, User) ->
    lists:member(User, State#channel_state.users).
