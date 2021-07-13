# Functors.jl

Functors.jl provides a set of tools to represent [functors](https://en.wikipedia.org/wiki/Functor_(functional_programming)). Functors are a powerful means to apply functions to generic objects without changing their structure.

Functors can be used in a variety of ways. One is to traverse a complicated or nested structure as a tree and apply a function `f` to its fields.

For large models it can be cumbersome or inefficient to work with parameters as one big, flat vector, and structs help manage complexity; but you also want to easily operate over all parameters at once, e.g. for changing precision or applying an optimiser update step.

!!! warning "Not everything should be a functor!"
    Due to its generic nature it is very attractive to mark several structures as [`@functor`](@ref) when it may not be quite safe to do so.
    Typically, since any function `f` is applied to the leaves of the tree, but it is possible for some functions to require dispatching on the specific type of the fields causing some methods to be missed entirely.
    Examples of this include element types of arrays which typically have their own mathematical operations defined. Adding a [`@functor`](@ref) to such a type would end up missing methods such as `+(::MyElementType, ::MyElementType)`. Think `RGB` from Colors.jl.

When one marks a structure as [`@functor`](@ref) it means that Functors.jl is allowed to look into the fields of the instances of the struct and modify them. This is achieved through [`Functors.fmap`](@ref).

The workhorse of fmap is actually a lower level function, functor:

```julia-repl
julia> using Functors

julia> struct Foo
         x
         y
       end

julia> @functor Foo

julia> foo = Foo(1, [1, 2, 3]) # notice all the elements are integers

julia> xs, re = Functors.functor(foo)
((x = 1, y = [1, 2, 3]), var"#21#22"())

julia> re(map(float, xs)) # element types have been switched out for floating point numbers
Foo(1.0, [1.0, 2.0, 3.0])
```

`functor` returns the parts of the object that can be inspected, as well as a reconstruction function (shown as `re`) that takes those values and restructures them back into an object of the original type.

To include only certain fields of a struct, one can pass a tuple of field names to [`@functor`](@ref):

```julia-repl
julia> struct Baz
         x
         y
       end

julia> @functor Baz (x,)

julia> model = Baz(1, 2)
Baz(1, 2)

julia> fmap(float, model)
Baz(1.0, 2)
```

Any field not in the list will be passed through as-is during reconstruction. This is done by invoking the default constructor, so structs that define custom inner constructors are expected to provide one that acts like the default.

