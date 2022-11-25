# Functors.jl

Functors.jl provides a set of tools to represent [functors](https://en.wikipedia.org/wiki/Functor_(functional_programming)). Functors are a powerful means to apply functions to generic objects without changing their structure.

The most straightforward use is to traverse a complicated nested structure as a tree, and apply a function `f` to every field it encounters along the way.

For large models it can be cumbersome or inefficient to work with parameters as one big, flat vector, and structs help manage complexity; but it may be desirable to easily operate over all parameters at once, e.g. for changing precision or applying an optimiser update step.

## Basic Usage and Implementation

By default, julia types are marked as [`@functor`](@ref)s, meaning that Functors.jl is allowed to look into the fields of the instances of the struct and modify them. This is achieved through [`Functors.fmap`](@ref).

The workhorse of `fmap` is actually a lower level function, functor:

```julia-repl
julia> using Functors

julia> struct Foo
         x
         y
       end

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

Any field not in the list will be passed through as-is during reconstruction. This is done by invoking the default constructor accepting all fields as arguments, so structs that define custom inner constructors are expected to provide one that acts like the default. 

The use of `@functor` with no fields argument as in `@functor Baz` is equivalent to `@functor Baz fieldnames(Baz)`
and also equivalent to avoiding `@functor` altogether.

Using [`@leaf`](@ref) instead of [`@functor`](@ref) will prevent the fields of a struct from being traversed. 

!!! warning "Change to opt-out behaviour in v0.5"
    Previous releases of functors, up to v0.4, used an opt-in behaviour where structs were not functors unless marked with `@functor`. This was changed in v0.5 to an opt-out behaviour where structs are functors unless marked with `@leaf`.

## Appropriate Use

Typically, since any function `f` is applied to the leaves of the tree, but it is possible for some functions to require dispatching on the specific type of the fields causing some methods to be missed entirely.

Examples of this include element types of arrays which typically have their own mathematical operations defined. Adding a [`@functor`](@ref) to such a type would end up missing methods such as `+(::MyElementType, ::MyElementType)`. Think `RGB` from Colors.jl.
