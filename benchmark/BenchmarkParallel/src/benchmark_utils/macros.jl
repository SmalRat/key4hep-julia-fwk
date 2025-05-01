function parse_kwargs_exprs(kwargs, d)
    for expr in kwargs
        if expr isa Expr && expr.head == :(=) && length(expr.args) == 2
            key = expr.args[1]
            value = expr.args[2]
            if key isa Symbol
                d[key] = value
            else
                error("Invalid key in keyword arguments: $key")
            end
        end
    end
end

macro custom_exitcode_on_error(ex, kwargs...)
    kwargs_dict = Dict{Symbol, Any}(:errmsg => nothing, :exitcode => 1)
    parse_kwargs_exprs(kwargs, kwargs_dict)

    errmsg = kwargs_dict[:errmsg]
    exitcode = kwargs_dict[:exitcode]

    return quote
        try
            $(esc(ex))
        catch
            if $errmsg !== nothing
                @error $errmsg
            end
            atexit(() -> exit($exitcode))
            rethrow()
        end
    end
end
