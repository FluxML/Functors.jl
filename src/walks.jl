abstract type AbstractWalk end

struct DefaultWalk <: AbstractWalk end

function (::DefaultWalk)(recurse, x, ys...)
  func, re = functor(x)
  yfuncs = map(y -> functor(typeof(x), y)[1], ys)
  re(map(recurse, func, yfuncs...))
end

struct StructuralWalk <: AbstractWalk end

(::StructuralWalk)(recurse, x) = map(recurse, children(x))

struct ExcludeWalk{T, F, G} <: AbstractWalk
  walk::T
  fn::F
  exclude::G
end

(walk::ExcludeWalk)(recurse, x, ys...) =
  walk.exclude(x) ? walk.fn(x, ys...) : walk.walk(recurse, x, ys...)

struct NoKeyword end

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
