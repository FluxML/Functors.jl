# Functors.jl

Functors.jl provides a set of tools to represent [functors](https://en.wikipedia.org/wiki/Functor_(functional_programming)). Functors are a powerful means to apply functions to generic objects without changing their structure.

The most straightforward use is to traverse a complicated nested structure as a tree, and apply a function `f` to every field it encounters along the way.

For large machine learning models it can be cumbersome or inefficient to work with parameters as one big, flat vector, and structs help manage complexity; but it may be desirable to easily operate over all parameters at once, e.g. for changing precision or applying an optimiser update step.

## Basic Usage and Implementation

By default, Functors.jl is allowed to look into the fields of the instances of any struct and modify them. This can be achieved through [`fmap`](@ref). To opt-out of this behaviour and mark a custom type as non traversable, use the macro [`@leaf`](@ref).

The workhorse of `fmap` is actually a lower level function, [`functor`](@ref Functors.functor):

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

The use of `@functor` with no fields argument as in `@functor Baz` is equivalent to `@functor Baz fieldnames(Baz)` and also equivalent to avoiding `@functor` altogether.

Using [`@leaf`](@ref) instead of [`@functor`](@ref) will prevent the fields of a struct from being traversed.

!!! warning "Change to opt-out behaviour in v0.5"
    Previous releases of functors, up to v0.4, used an opt-in behaviour where structs were leaves functors unless marked with `@functor`. This was changed in v0.5 to an opt-out behaviour where structs are functors unless marked with `@leaf`.

## Which types are leaves?

By default all composite types in are functors and can be traversed, unless marked with [`@leaf`](@ref). 

The following types instead are explicitly marked as leaves in Functors.jl:
- `Type`
- `Number`.
- `AbstractArray{<:Number}`, except for the wrappers `Transpose`, `Adjoint`, and `PermutedDimsArray`.
- `AbstractRNG`.
- `AbstractString`, `AbstractChar`, `AbstractPattern`, `AbstractMatch`.

This is because in typical application the internals of these are abstracted away and it is not desirable to traverse them.

## What if I get an error?

Since by default Functors.jl tries to traverse most types e.g. when using [`fmap`](@ref), it is possible it fails in case the type has not an appropriate constructor. If use experience this issue, you have a few alternatives:
- Mark the type as a leaf using [`@leaf`](@ref) 
- Use the `@functor` macro to specify which fields to traverse.
- Define an appropriate constructor for the type.

If you are not able to traverse types in julia Base, please open an issue.
