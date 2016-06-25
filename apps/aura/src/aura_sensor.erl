%%
%%   Copyright 2016 Zalando SE
%%
%%   Licensed under the Apache License, Version 2.0 (the "License");
%%   you may not use this file except in compliance with the License.
%%   You may obtain a copy of the License at
%%
%%       http://www.apache.org/licenses/LICENSE-2.0
%%
%%   Unless required by applicable law or agreed to in writing, software
%%   distributed under the License is distributed on an "AS IS" BASIS,
%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%   See the License for the specific language governing permissions and
%%   limitations under the License.
%%
-module(aura_sensor).
-behaviour(pipe).

-export([
   start_link/2,
   init/1,
   free/2,
   dirty/3,
   fresh/3
]).

%% see 
%%   https://en.wikipedia.org/wiki/Exponential_smoothing
-define(A, 0.1).

%% aggregation window
-define(W, 1000).

%%%----------------------------------------------------------------------------   
%%%
%%% factory
%%%
%%%----------------------------------------------------------------------------   

start_link(Ns, Urn) ->
   pipe:start_link(?MODULE, [Ns, Urn], []).


init([Ns, {urn, _, _} = Urn]) ->
   ok = pns:register(Ns, Urn, self()),
   {ok, dirty,
      window(
         #{
            fd   => aura:fd(),
            urn  => Urn,
            x    => 0.0,
            tts  => tempus:timer(?W, tts)   
         }
      )
   }.

free(_, _State) ->
   ok.

%%%----------------------------------------------------------------------------   
%%%
%%% pipe
%%%
%%%----------------------------------------------------------------------------   

%% @todo: use data structure provided by 'clue' library

%%
%%
dirty({get, _}, Pipe, #{x := X} = State) ->
   pipe:ack(Pipe, {ok, X}),
   {next_state, dirty, State};

dirty({_, _} = X, Pipe, State) ->
   pipe:ack(Pipe, ok),
   {next_state, fresh, update(X, State)};

dirty(tts, _Pipe, #{tts := TTS} = State) ->
   {next_state, dirty, 
      State#{
         tts => tempus:reset(TTS, tts)
      }
   }.

%%
%%
fresh({get, _}, Pipe, #{x := X} = State) ->
   pipe:ack(Pipe, {ok, X}),
   {next_state, fresh, State};

fresh({_, _} = X, Pipe, State) ->
   pipe:ack(Pipe, ok),
   {next_state, fresh, update(X, State)};

fresh(tts, _Pipe, #{tts := TTS} = State0) ->
   State = window(append(State0)),
   {next_state, dirty, 
      State#{
         tts => tempus:reset(TTS, tts)
      }
   }.      

%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   

%%
%%
update({_, X}, #{urn := {urn, <<"g">>, _}, x := X0} = State) ->
   State#{
      x => ?A * X + (1 - ?A) * X0
   };

update({_, X}, #{urn := {urn, <<"c">>, _}, x := X0} = State) ->
   State#{
      x => X0 + X
   };

update(_, State) ->
   State.

%%
%%
append(#{urn := {urn, <<"g">>, _} = Urn, ta := T, x := X, fd := FD} = State) ->
   chronolog:append(FD, Urn, [{T, erlang:trunc(X)}]),
   State;

append(#{urn := {urn, <<"c">>, _} = Urn, ta := T, x := X, fd := FD} = State) ->
   chronolog:append(FD, Urn, [{T, erlang:trunc(X)}]),
   State#{x => 0.0}.

%%
%% 
window(State) ->
   Ta = os:timestamp(),
   Tb = tempus:add(Ta, ?W),
   State#{ta => Ta, tb => Tb}.