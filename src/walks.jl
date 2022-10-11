"""
    AbstractWalk

Any walk for use with [`fmap`](@ref) should inherit from this type.
A walk subtyping `AbstractWalk` must satisfy the walk function interface:
```julia
struct MyWalk <: AbstractWalk end

function (::MyWalk)(recurse, x, ys...)
  # implement this
end
```
The walk function is called on a node `x` in a Functors tree.
It may also be passed associated nodes `ys...` in other Functors trees.
The walk function recurses further into `(x, ys...)` by calling
`recurse` on the child nodes.
The choice of which nodes to recurse and in what order is custom to the walk.
"""
abstract type AbstractWalk end

"""
    AnonymousWalk(walk_fn)

Wrap a `walk_fn` so that `AnonymousWalk(walk_fn) isa AbstractWalk`.
This type only exists for backwards compatability and should be directly used.
Attempting to wrap an existing `AbstractWalk` is a no-op (i.e. it is not wrapped).
"""
struct AnonymousWalk{F} <: AbstractWalk
  walk::F
end
# do not wrap an AbstractWalk
AnonymousWalk(walk::AbstractWalk) = walk

(walk::AnonymousWalk)(recurse, x, ys...) = walk.walk(recurse, x, ys...)

"""
    DefaultWalk()

The default walk behavior for Functors.jl.
Walks all the [`Functors.children`](@ref) of trees `(x, ys...)` based on
the structure of `x`.
The resulting mapped child nodes are restructured into the type of `x`.

See [`fmap`](@ref) for more information.
"""
struct DefaultWalk <: AbstractWalk end

function (::DefaultWalk)(recurse, x, ys...)
  func, re = functor(x)
  yfuncs = map(y -> functor(typeof(x), y)[1], ys)
  re(map(recurse, func, yfuncs...))
end

"""
    StructuralWalk()

A structural variant of [`Functors.DefaultWalk`](@ref).
The recursion behavior is identical, but the mapped children are not restructured.

See [`fmapstructure`](@ref) for more information.
"""
struct StructuralWalk <: AbstractWalk end

(::StructuralWalk)(recurse, x) = map(recurse, children(x))

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

(walk::ExcludeWalk)(recurse, x, ys...) =
  walk.exclude(x) ? walk.fn(x, ys...) : walk.walk(recurse, x, ys...)

struct NoKeyword end

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

function (walk::CachedWalk)(recurse, x, ys...)
  if haskey(walk.cache, x)
    return walk.prune isa NoKeyword ? walk.cache[x] : walk.prune
  else
    walk.cache[x] = walk.walk(recurse, x, ys...)
    return walk.cache[x]
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
function (walk::CollectWalk)(recurse, x)
  x in walk.cache && return walk.output
  # to exclude, we wrap this walk in ExcludeWalk
  push!(walk.cache, x)
  push!(walk.output, x)
  map(recurse, children(x))

  return walk.output
end
