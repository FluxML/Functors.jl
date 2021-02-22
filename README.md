# Functors

Functors.jl provides a mechanism – really more of a design pattern – for dealing with large structures containing numerical parameters, as in machine learning and optimisation. For large models it can be cumbersome or inefficient to work with parameters as one big, flat vector, and structs help manage complexity; but you also want to easily operate over all parameters at once, e.g. for changing precision or applying an optimiser update step.

Functors.jl provides `fmap` to make those things easy, acting as a 'map over parameters':

```julia
julia> using Functors

julia> struct Foo
         x
         y
       end

julia> @functor Foo

julia> model = Foo(1, [1, 2, 3])
Foo(1, [1, 2, 3])

julia> fmap(float, model)
Foo(1.0, [1.0, 2.0, 3.0])
```

It works also with deeply-nested models:

```julia
julia> struct Bar
         x
       end

julia> @functor Bar

julia> model = Bar(Foo(1, [1, 2, 3]))
Bar(Foo(1, [1, 2, 3]))

julia> fmap(float, model)
Bar(Foo(1.0, [1.0, 2.0, 3.0]))
```

The workhorse of `fmap` is actually a lower level function, `functor`:

```julia
julia> xs, re = functor(Foo(1, [1, 2, 3]))
((x = 1, y = [1, 2, 3]), var"#21#22"())

julia> re(map(float, xs))
Foo(1.0, [1.0, 2.0, 3.0])
```

`functor` returns the parts of the object that can be inspected, as well as a `re` function that takes those values and restructures them back into an object of the original type.

To include only certain fields, pass a tuple of field names to `@functor`:

```julia
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

Any field not in the list will not be returned by `functor` and passed through as-is during reconstruction. This is done by invoking the default constructor, so structs that define custom inner constructors are expected to provide one that acts like the default.

It is also possible to implement `functor` by hand when greater flexibility is required. See [here](https://github.com/FluxML/Functors.jl/issues/3) for an example.

For a discussion regarding the need for a `cache` in the implementation of `fmap`, see [here](https://github.com/FluxML/Functors.jl/issues/2).

To control the depth of descent by `fmap`, the keyword `predicate` can be used:
```julia
julia> using CUDA

julia> x = ['a', 'b', 'c'];

julia> fmap(cu, x)
3-element Array{Char,1}:
 'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)
 'b': ASCII/Unicode U+0062 (category Ll: Letter, lowercase)
 'c': ASCII/Unicode U+0063 (category Ll: Letter, lowercase)

julia> fmap(cu, x; predicate = CUDA.isbits)
3-element CuArray{Char,1}:
 'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)
 'b': ASCII/Unicode U+0062 (category Ll: Letter, lowercase)
 'c': ASCII/Unicode U+0063 (category Ll: Letter, lowercase)
```