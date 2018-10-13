using Test, Hose

import Base: macroexpand
macroexpand(q) = macroexpand(Main, q)

#No change to nonhoses functionality
@test macroexpand( :(@hose a) ) == :a #doesn't change single inputs
@test macroexpand( :(@hose b(a)) ) == :(b(a)) #doesn't change inputs that a function applications

#Compatable with Julia 1.3 piping functionality
@test macroexpand( :(@hose a|>b) ) == :(b(a)) #basic
@test macroexpand( :(@hose a|>b|>c) ) == :(c(b(a)))  #Keeps chaining 3
@test macroexpand( :(@hose a|>b|>c|>d) ) == :(d(c(b(a)))) #Keeps chaining 4

@test macroexpand( :(@hose a |> b(x)) ) == :(b(a, x))  # Applying to function adds the LHS as the first argument Lazy.jl style
@test macroexpand( :(@hose a(x)|>b ) ) == :(b(a(x)))   #feeding functioncall results on wards

@test macroexpand(:(@hose 1|>a)) ==:(a(1)) #Works with literals (int)
@test macroexpand(:(@hose "foo"|>a)) == :(a("foo")) #Works with literal (string)
@test macroexpand( :(@hose a|>bb[2])) == :((bb[2])(a)) #Should work with RHS that is a array reference



#Marked locations
@test macroexpand( :(@hose a |> _)) == :(a) #Identity works
@test macroexpand( :(@hose a |> _[b])) == :(a[b]) #Indexing works

@test macroexpand( :(@hose a|>b(_) ) ) == :(b(a)) #Marked location only
@test macroexpand( :(@hose a|>b(x,_) ) ) == :(b(x,a)) # marked 2nd (and last)
@test macroexpand( :(@hose a|>b(_,x) ) ) == :(b(a,x)) # marked first
@test macroexpand( :(@hose a|>b(_,_) ) ) == :(b(a,a)) # marked double (Not certain if this is a good idea)
@test macroexpand( :(@hose a|>bb[2](x,_))) == :((bb[2])(x,a)) #Should work with RHS that is a array reference

#Macros and blocks
macro testmacro1(arg)
    esc(:($arg + 42))
end
macro testmacro2(arg, n)
    esc(:($arg + $n))
end
@test macroexpand( :(@hose a |> @testmacro1 ) ) == :(a + 42) # Can hose into macros like functions Lazy.jl style
@test macroexpand( :(@hose a |> @testmacro2 _ 3 ) ) == :(a + 3) # Can hose into macros
@test macroexpand( :(@hose a |> begin b = _; c + b + _ end )) == :(
                                begin b = a; c + b + a end)

#marked Unpacking
@test macroexpand( :(@hose a|>b(_...) ) ) == :(b(a...)) # Unpacking
@test macroexpand( :(@hose a|>bb[2](_...))) == :((bb[2])(a...)) #Should work with RHS of arry ref and do unpacking

#Mixing modes
@test macroexpand( :(@hose a|>b|>c(_) ) ) == :(c(b(a)))
@test macroexpand( :(@hose a|>b(x,_)|>c|>d(_,y) ) ) == :(d(c(b(x,a)),y))
