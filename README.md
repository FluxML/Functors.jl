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

For a discussion regarding implementing functors for which only a subset of the fields are "seen" by `functor`, see [here](https://github.com/FluxML/Functors.jl/issues/3#issuecomment-626747663).

For a discussion regarding the need for a `cache` in the implementation of `fmap`, see [here](https://github.com/FluxML/Functors.jl/issues/2).
