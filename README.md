# Functors.jl

[![][docs-stable-img]][docs-stable-url]
[![][docs-dev-img]][docs-dev-url]
[![][action-img]][action-url]

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://fluxml.ai/Functors.jl/stable/

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://fluxml.ai/Functors.jl/dev/

[action-img]: https://github.com/FluxML/Functors.jl/workflows/CI/badge.svg
[action-url]: https://github.com/FluxML/Functors.jl/actions

Functors.jl provides tools to express a powerful design pattern for dealing with large / nested structures, as in machine learning and optimisation. For large machine learning models it can be cumbersome or inefficient to work with parameters as one big, flat vector, and structs help manage complexity; but it is also desirable to easily operate over all parameters at once, e.g. for changing precision or applying an optimiser update step.

## Basic Usage

Functors.jl provides `fmap` to make those things easy, acting as a 'map over parameters':

```julia
julia> using Functors

julia> struct Foo
         x
         y
       end

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

julia> model = Bar(Foo(1, [1, 2, 3]))
Bar(Foo(1, [1, 2, 3]))

julia> fmap(float, model)
Bar(Foo(1.0, [1.0, 2.0, 3.0]))
```

> [!NOTE]
> Up to to v0.4, Functors.jl's functionality had to be opted in on custom types via the `@functor Foo` macro call. 
> With v0.5 instead, this is no longer necessary: by default any type is recursively traversed up to the leaves
> and `ConstructionBase.constructorof` is used to reconstruct it.
> In order to opt-out of this behaviour and make a type non traversable you can use `@leaf Foo`.
>
> Most users should be unaffected by the change and could remove `@functor` from their custom types.

## Further Details

The workhorse of `fmap` is actually a lower level function, `functor`:

```julia
julia> children, reconstruct = Functors.functor(Foo(1, [1, 2, 3]))
((x = 1, y = [1, 2, 3]), Functors.var"#3#6"{DataType}(Foo))

julia> reconstruct(map(float, children))
Foo(1.0, [1.0, 2.0, 3.0])
```

`functor` returns the parts of the object that can be inspected, as well as a `reconstruct` function that takes those values and restructures them back into an object of the original type.

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

Use `exclude` for more fine-grained control over whether `fmap` descends into a particular value (the default is `exclude = Functors.isleaf`):

```julia
julia> using CUDA

julia> x = ['a', 'b', 'c'];

julia> fmap(cu, x)
3-element Array{Char,1}:
 'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)
 'b': ASCII/Unicode U+0062 (category Ll: Letter, lowercase)
 'c': ASCII/Unicode U+0063 (category Ll: Letter, lowercase)

julia> fmap(cu, x; exclude = x -> CUDA.isbitstype(eltype(x)))
3-element CuArray{Char,1}:
 'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)
 'b': ASCII/Unicode U+0062 (category Ll: Letter, lowercase)
 'c': ASCII/Unicode U+0063 (category Ll: Letter, lowercase)
```

## Related Packages
- [StructWalk.jl](https://github.com/chengchingwen/StructWalk.jl)
