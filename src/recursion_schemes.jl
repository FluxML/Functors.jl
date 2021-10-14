# Ordinarily separate instances of mutable types would have distinct objectids
# (or at least fail a === test), but String is an exception to both.
# This function exists purely to handle that edge case.
iscacheable(x) = ismutable(x)
iscacheable(::String) = false

## Generalized folds (Catamorphisms)
struct Fold{F,I,C}
    fn::F
    isleaf::I
    cache::C
end

function _fold_helper(f, x)
    y = project(x)
    f.fn(f.isleaf(y) ? y : fmap(f, y))
end

function _fold_helper(f, xs...)
    ys = map(project, xs)
    # TODO are there times when we _should_ recurse despite a leaf?
    any(f.isleaf, ys) ? f.fn(ys...) : f.fn(fmap((xs′...) -> f(xs′...), ys...))
end

# TODO add fast paths when f.cache === nothing?
(f::Fold)(x) = !iscacheable(x) ? get!(() -> _fold_helper(f, x), f.cache, x) : _fold_helper(f, x)
function (f::Fold)(xs...) 
    all(iscacheable, xs) || _fold_helper(f, xs...)
    get!(() -> _fold_helper(f, xs...), f.cache, xs)
end

"""
    fold(f, x; isleaf=Functors.isleaf, cache=IdDict())
    fold(f, xs...; isleaf=Functors.isleaf, cache=IdDict())

Generalized fold over functors.
The fancy functional programming term for this is a "catamorphism"
(see [here](https://blog.sumtypeofway.com/posts/recursion-schemes-part-2.html) for a good intro).

`f` is a function that takes one or more [`Functor`](@ref)s and returns any value.

To control when `fold` stops recursing, pass a custom `isleaf` predicate.
This defaults to [`Functors.isleaf`](@ref).

If `x` doesn't have any structural sharing, or can be safely unpacked into a tree without sharing,
Setting `cache=nothing` will provide a small speedup.
If you're not sure whether this applies, just leave it as-is.

When multiple inputs `xs...` are passed, `fold` will return a functor based on the structure of the first input.
Just like `map` and `zip`, `fold` will stop recursing once any it hits a leaf node in any input.
"""
fold(f, x; isleaf=isleaf, cache=IdDict()) = Fold(f, isleaf, cache)(x)
fold(f, xs...; isleaf=isleaf, cache=IdDict()) = Fold(f, isleaf, cache)(xs...)

"""
Alias for [`Functors.fold`](@ref)
"""
const cata = fold


## Generalized unfolds (Anamorphisms)
struct Unfold{F}
    fn::F
end

_unfold_helper(u, x) = embed(fmap(u, u.fn(x)))
_unfold_helper(u, xs...) = map(embed, fmap((ys...) -> u(ys...), u.fn(xs...)))

(u::Unfold)(x, xs...) = _unfold_helper(u, x, xs...)

"""
    unfold(f, x)
    unfold(f, xs...)

Generalized unfold producing functors.
The fancy functional programming term for this is an "anamorphism"
(see [here](https://blog.sumtypeofway.com/posts/recursion-schemes-part-2.html) for a good intro).

`f` is a function that takes one or more inputs and returns a [`Functor`](@ref).
"""
unfold(f, x) = Unfold(f)(x)
unfold(f, xs...) = Unfold(f)(xs...)

"""
Alias for [`Functors.unfold`](@ref)
"""
const ana = unfold


## Convenience functions
"""
    rfmap(f, x; isleaf=Functors.isleaf, walk = Functors._default_walk)
    rfmap(f, xs...; isleaf=Functors.isleaf, walk = Functors._default_walk)

A recursive, structure and type preserving `map` that works on nested functors.
`rfmap` traverses and transforms every leaf node identified by `isleaf` with `f`.

To control when `fold` stops recursing, pass a custom `isleaf` predicate.
This defaults to [`Functors.isleaf`](@ref).

When multiple inputs `xs...` are passed, `rfmap` will return a functor based on the structure of the first input.
Just like `map` and `zip`, `rfmap` will stop recursing once any it hits a leaf node in any input.

# Examples
```jldoctest
julia> struct Foo; x; y; end
julia> @functor Foo
julia> struct Bar; x; end
julia> @functor Bar
julia> m = Foo(Bar([1,2,3]), (4, 5));
julia> rfmap(x -> 2x, m)
Foo(Bar([2, 4, 6]), (8, 10))
julia> rfmap(string, m)
Foo(Bar("[1, 2, 3]"), ("4", "5"))
```
"""
rfmap(f, x; isleaf=isleaf) = fold(embed ∘ f, x, isleaf=isleaf)
rfmap(f, xs...; isleaf=isleaf) = fold(xs...; isleaf=isleaf) do (ys...)
    embed(length(ys) > 1 ? f(ys...) : only(ys))
end