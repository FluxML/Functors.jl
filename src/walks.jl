_map(f, x...) = map(f, x...)
_map(f, x::Dict, ys...) = Dict(k => f(v, (y[k] for y in ys)...) for (k, v) in x)

_values(x) = x
_values(x::Dict) = values(x)

"""
    AbstractWalk

Any walk for use with [`fmap`](@ref) should inherit from this type.
A walk subtyping `AbstractWalk` must satisfy the walk function interface:
```julia
struct MyWalk <: Functors.AbstractWalk end

function (::MyWalk)(outer_walk::Functors.AbstractWalk, x, ys...)
  # implement this
end
```
The walk function is called on a node `x` in a Functors tree.
It may also be passed associated nodes `ys...` in other Functors trees.
The walk function recurses further into `(x, ys...)` by calling
`outer_walk` on the child nodes.
The choice of which nodes to recurse and in what order is custom to the walk.
By default, `outer_walk` it set to the walk being called,
i.e. `(walk::AbstractWalk)(x, ys...) = walk(walk, x, ys...)`,
but in general it allows for greater flexibility (e.g. nesting walks in one another).
"""
abstract type AbstractWalk end

(walk::AbstractWalk)(x, ys...) = walk(walk, x, ys...)

"""
    AnonymousWalk(walk_fn)

Wrap a `walk_fn` so that `AnonymousWalk(walk_fn) isa AbstractWalk`.
This type only exists for backwards compatability and should not be directly used.
Attempting to wrap an existing `AbstractWalk` is a no-op (i.e. it is not wrapped).
"""
struct AnonymousWalk{F} <: AbstractWalk
  walk::F

  function AnonymousWalk(walk::F) where F
    Base.depwarn("Wrapping a custom walk function as an `AnonymousWalk`. Future versions will only support custom walks that explicitly subtype `AbstractWalk`.", :AnonymousWalk)
    return new{F}(walk)
  end
end
# do not wrap an AbstractWalk
AnonymousWalk(walk::AbstractWalk) = walk

(walk::AnonymousWalk)(outer_walk::AbstractWalk, x, ys...) = walk.walk(outer_walk, x, ys...)

"""
    DefaultWalk()

The default walk behavior for Functors.jl.
Walks all the [`Functors.children`](@ref) of trees `(x, ys...)` based on
the structure of `x`.
The resulting mapped child nodes are restructured into the type of `x`.

See [`fmap`](@ref) for more information.
"""
struct DefaultWalk <: AbstractWalk end

function (::DefaultWalk)(outer_walk::AbstractWalk, x, ys...)
  func, re = functor(x)
  yfuncs = map(y -> functor(typeof(x), y)[1], ys)
  re(_map(outer_walk, func, yfuncs...))
end

"""
    StructuralWalk()

A structural variant of [`Functors.DefaultWalk`](@ref).
The recursion behavior is identical, but the mapped children are not restructured.

See [`fmapstructure`](@ref) for more information.
"""
struct StructuralWalk <: AbstractWalk end

(::StructuralWalk)(outer_walk::AbstractWalk, x) = _map(outer_walk, children(x))

"""
    ExcludeWalk(walk, fn, exclude)

A walk that recurses nodes `(x, ys...)` according to `walk`,
except when `exclude(x)` is true.
Then, `fn(x, ys...)` is applied instead of recursing further.

Typically wraps an existing `walk` for use with [`fmap`](@ref).
"""
struct ExcludeWalk{T, F, G} <: AbstractWalk
  walk::T
  fn::F
  exclude::G
end

(walk::ExcludeWalk)(outer_walk::AbstractWalk, x, ys...) =
  walk.exclude(x) ? walk.fn(x, ys...) : walk.walk(outer_walk, x, ys...)

struct NoKeyword end

usecache(::Union{AbstractDict, AbstractSet}, x) =
  isleaf(x) ? anymutable(x) : ismutable(x)
usecache(::Nothing, x) = false

@generated function anymutable(x::T) where {T}
  ismutabletype(T) && return true
  subs =  [:(anymutable(getfield(x, $f))) for f in QuoteNode.(fieldnames(T))]
  return Expr(:(||), subs...)
end

"""
    CachedWalk(walk[; prune])

A walk that recurses nodes `(x, ys...)` according to `walk` and storing the
output of the recursion in a cache indexed by `x` (based on object ID).
Whenever the cache already contains `x`, either:
- `prune` is specified, then it is returned, or
- `prune` is unspecified, and the previously cached recursion of `(x, ys...)`
  returned.

Typically wraps an existing `walk` for use with [`fmap`](@ref).
"""
struct CachedWalk{T, S} <: AbstractWalk
  walk::T
  prune::S
  cache::IdDict{Any, Any}
end
CachedWalk(walk; prune = NoKeyword(), cache = IdDict()) =
  CachedWalk(walk, prune, cache)

function (walk::CachedWalk)(outer_walk::AbstractWalk, x, ys...)
  should_cache = usecache(walk.cache, x)
  if should_cache && haskey(walk.cache, x)
    return walk.prune isa NoKeyword ? walk.cache[x] : walk.prune
  else
    ret = walk.walk(outer_walk, x, ys...)
    if should_cache
      walk.cache[x] = ret
    end
    return ret
  end
end

"""
    CollectWalk()

A walk that recurses into a node `x` via [`Functors.children`](@ref),
storing the recursion history in a cache.
The resulting ordered recursion history is returned.

See [`fcollect`](@ref) for more information.
"""
struct CollectWalk <: AbstractWalk
  cache::Base.IdSet{Any}
  output::Vector{Any}
end
CollectWalk() = CollectWalk(Base.IdSet(), Any[])

# note: we don't have an `OrderedIdSet`, so we use an `IdSet` for the cache
# (to ensure we get exactly 1 copy of each distinct array), and a usual `Vector`
# for the results, to preserve traversal order (important downstream!).
function (walk::CollectWalk)(outer_walk::AbstractWalk, x)
  if usecache(walk.cache, x) && (x in walk.cache)
    return walk.output
  end
  # to exclude, we wrap this walk in ExcludeWalk
  usecache(walk.cache, x) && push!(walk.cache, x)
  push!(walk.output, x)
  _map(outer_walk, children(x))

  return walk.output
end

"""
    IterateWalk()

A walk that walks all the [`Functors.children`](@ref) of trees `(x, ys...)` 
and concatenates the iterators of the children via
[`Iterators.flatten`](https://docs.julialang.org/en/v1/base/iterators/#Base.Iterators.flatten).
The resulting iterator is returned.

When used with [`fmap`](@ref), the provided function `f` should
return an iterator. For example, to iterate through
the square of every scalar value:
```jldoctest iterate
julia> x = ([1, 2, 3], 4, (5, 6, [7, 8]));

julia> make_iterator(x) = x isa AbstractVector ? x.^2 : (x^2,);

julia> iter = fmap(make_iterator, x; walk=Functors.IterateWalk(), cache=nothing);

julia> collect(iter)
8-element Vector{Int64}:
  1
  4
  9
 16
 25
 36
 49
 64
```
We can also simultaneously iterate through multiple functors:
```@jldoctest iterate
julia> y = ([8, 7, 6], 5, (4, 3, [2, 1]));

julia> make_zipped_iterator(x, y) = zip(make_iterator(x), make_iterator(y));

julia> zipped_iter = fmap(make_zipped_iterator, x, y; walk=Functors.IterateWalk(), cache=nothing);

julia> collect(zipped_iter)
8-element Vector{Tuple{Int64, Int64}}:
 (1, 64)
 (4, 49)
 (9, 36)
 (16, 25)
 (25, 16)
 (36, 9)
 (49, 4)
 (64, 1)
```
"""
struct IterateWalk <: AbstractWalk end

function (walk::IterateWalk)(outer_walk::AbstractWalk, x, ys...)
  func, _ = functor(x)
  yfuncs = map(y -> functor(typeof(x), y)[1], ys)
  return Iterators.flatten(_map(outer_walk, func, yfuncs...))
end
