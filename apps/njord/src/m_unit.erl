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
%% @doc
%%   experimental unit test monad
-module(m_unit).

-export([return/1, fail/1, '>>='/2]).
-export([new/1, eq/2]).

%%%----------------------------------------------------------------------------   
%%%
%%% state monad
%%%
%%%----------------------------------------------------------------------------   

return(X) -> 
   fun(State) -> 
      Urn  = lens:get(id(), State),
      Unit = lens:get(unit(), State),
      [{Urn, Unit}|maps:remove(unit, State)] 
   end.

fail(X) ->
   m_state:fail(X).

'>>='(X, Fun) ->
   m_state:'>>='(X, Fun).


%%%----------------------------------------------------------------------------   
%%%
%%% asserts
%%%
%%%----------------------------------------------------------------------------   

%%
%%
id()   -> lens:c([lens:map(fd, #{}), lens:map(id,  none)]).
code() -> lens:c([lens:map(unit, #{}), lens:map(code,  none)]).
head() -> lens:c([lens:map(unit, #{}), lens:map(head,    [])]).
data() -> lens:c([lens:map(unit, #{}), lens:map(data,  none)]).
unit() -> lens:c([lens:map(unit, #{}), lens:map(unit,    [])]).

%%
%%
new([{Code, _, Head, _} | Payload]) ->
   fun(State0) ->
      Mime   = lens:get(lens:pair('Content-Type'), Head),
      Data   = decode(Mime, erlang:iolist_to_binary(Payload)),
      State1 = lens:put(code(), Code, State0),
      State2 = lens:put(head(), Head, State1),
      State3 = lens:put(data(), Data, State2),
      [Data|State3]      
   end.

decode({_, <<"json">>}, Payload) ->
   jsx:decode(erlang:iolist_to_binary(Payload));

decode(_, Payload) ->
   erlang:iolist_to_binary(Payload).

%%
%%
eq(Lens, Value) ->
   fun(State) ->
      Expect = value(Value),
      Actual = scenario:lens(Lens, lens:get(data(), State)),
      Units  = lens:get(unit(), State),
      Unit   = #{pass => Expect =:= Actual, lens => Lens, expect => Expect, actual => Actual},
      [ok|lens:put(unit(), [Unit|Units], State)]      
   end.

%%
%%
value(X)
 when is_list(X) ->
   scalar:s(X);
value(X) ->
   X.
