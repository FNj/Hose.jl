"""
**Hose.jl** is for the situations where pipe is just not flexible enough.
"""
module Hose

export @hose

const PLACEHOLDER = :_

function rewrite_apply(ff::Symbol, target, b::Bool = false)
    if b
        :(broadcast($ff,$target))
    else
        :($ff($target)) # Function/macro application
    end
end

function rewrite_apply(ff::Expr, target, b::Bool = false)
    if ff.head == :call
        insert!(ff.args, 2, target)
        ff
    elseif ff.head == :macrocall
        insert!(ff.args, 3, target)
        ff
    elseif b
        :(broadcast($ff,$target))
    else
        :($ff($target))
    end
end

rewrite(ff::Symbol, target, b::Bool = false) = ifelse(ff == PLACEHOLDER, target, rewrite_apply(ff, target, b))

function rewrite(ff::Expr, target, b::Bool = false)
    replace(arg::Any) = arg  # For most things should be an identity.
    replace(arg::Symbol) = ifelse(arg == PLACEHOLDER, target, arg) # Placeholder symbol should get replaced.
    function replace(arg::Expr)
        rep = copy(arg)
        rep.args = map(replace,rep.args)
        rep
    end # Placeholder symbol should get replaced in expression arguments.

    rep_args = map(replace, ff.args)
    if ff.args != rep_args
        ff.args = rep_args # Placeholder subsitution
        ff
    else # No subsitution was done (no placeholder symbol found)
        rewrite_apply(ff, target, b) # Apply to a function/macro that is being returned by ff (ff could be a function call or something more complex).
    end
end

funnel(ee::Any) = ee # Identity for first (left most) input.

function funnel(ee::Expr)
    if (ee.args[1] == :|> || ee.args[1] == :.|>) # If ee is a call to |>
        target = funnel(ee.args[2]) # Process left hand side
        if (ee.args[1] == :.|>)
            rewrite(ee.args[3], target, true) # Rewrite |> right hand side using left hand side
        else
            rewrite(ee.args[3], target, false) # Rewrite |> right hand side using left hand side
        end
    else
        ee # Not in a piping situtation
    end
end

"""
```julia
    @hose(expression)
```
The `@hose` macro processes its argument so that you pipe the left hand side (LHS) into functions of several arguments, macros, blocks, just index the LHS etc. The placeholder symbol for the LHS on the RHS is the underscore (`_`).

Examples:
```julia
    @hose a |> b(x, _) # produces b(x, a)
    @hose a |> _[b] # produces a[b]
    @hose a |> @testmacro _ b # equivalent of @testmacro(a, b)
```

Also behaves like [Lazy.jl](https://github.com/MikeInnes/Lazy.jl) `@>` macro:
```julia
    @hose a |> b(x) # produces b(a, x)
    @hose a |> @testmacro # produces equivalent of @testmacro(a)
```

Standard piping works as well. For other examples see `test/runtests.jl`.
"""
macro hose(ee)
    esc(funnel(ee))
end

end
