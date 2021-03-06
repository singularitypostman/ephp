-module(ephp_lib_spl).
-author('manuel@altenwald.com').

-behaviour(ephp_lib).

-export([
    init_func/0,
    init_config/0,
    init_const/0,
    spl_autoload_call/3,
    spl_autoload_register/5,
    spl_autoload_unregister/3
]).

-include("ephp.hrl").

-spec init_func() -> ephp_lib:php_function_results().

init_func() -> [
    {spl_autoload_call, [{args, [string]}]},
    {spl_autoload_register, [
        {args, [callable, {boolean, false}, {boolean, false}]}
    ]},
    {spl_autoload_unregister, [{args, [callable]}]}
].

-spec init_config() -> ephp_lib:php_config_results().

init_config() -> [].

-spec init_const() -> ephp_lib:php_const_results().

init_const() -> [].

-spec spl_autoload_call(ephp:context_id(), line(), var_value()) -> undefined.

spl_autoload_call(Context, Line, {_, RawClassName}) ->
    {ClassNS, ClassName} = ephp_ns:parse(RawClassName),
    case ephp_class:get(Context, ClassNS, ClassName, spl) of
        {ok, _Class} ->
            undefined;
        {error, enoexist} ->
            ephp_stack:push(undefined, Line, <<"spl_autoload">>,
                            [ClassName], undefined, undefined),
            Classes = ephp_context:get_classes(Context),
            ExceptionName = <<"LogicException">>,
            Exception = ephp_class:instance(Classes, Context, Context,
                                            [], ExceptionName, Line),
            #ephp_object{class = Class} = ephp_object:get(Exception),
            #class_method{name = ConstructorName} =
                ephp_class:get_constructor(Classes, Class),
            Call = #call{type = object,
                         name = ConstructorName,
                         args = [<<"Class ", ClassName/binary,
                                   " could not be loaded">>],
                         line = Line},
            ephp_context:call_method(Context, Exception, Call),
            File = ephp_context:get_active_file(Context),
            Data = {File, ephp_error:get_line(Line), Exception},
            ephp_error:error({error, euncaught, Line, ?E_ERROR, Data})
    end.

-spec spl_autoload_register(ephp:context_id(), line(), var_value(), var_value(),
                            var_value()) -> boolean().

spl_autoload_register(Context, _Line,
                      {_, Function}, {_, _Thrown}, {_, RawPrepend}) ->
    Prepend = ephp_data:to_boolean(RawPrepend),
    Classes = ephp_context:get_classes(Context),
    ephp_class:register_loader(Classes, Function, Prepend),
    true.

-spec spl_autoload_unregister(ephp:context_id(), line(), var_value()) -> boolean().

spl_autoload_unregister(Context, _Line, {_, Function}) ->
    Classes = ephp_context:get_classes(Context),
    ephp_class:unregister_loader(Classes, Function).
