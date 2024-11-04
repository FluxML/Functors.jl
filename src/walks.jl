function _map(f, x, ys...)
  check_lenghts(x, ys...) || error("all arguments must have at least the same length of the firs one")
  map(f, x, ys...)
end

function check_lenghts(x, ys...)
  n = length(x)
  return all(y -> length(y) >= n, ys)
end

_map(f, x::Dict, ys...) = Dict(k => f(v, (y[k] for y in ys)...) for (k, v) in x)
_map(f, x::D, ys...) where {D<:AbstractDict} = 
  constructorof(D)([k => f(v, (y[k] for y in ys)...) for (k, v) in x]...)

_values(x) = x
_values(x::AbstractDict) = values(x)

_keys(x::D) where {D <: AbstractDict} = constructorof(D)(k => k for k in keys(x))
_keys(x::Tuple) = (keys(x)...,)
_keys(x::AbstractArray) = collect(keys(x))
_keys(x::NamedTuple{Ks}) where Ks = NamedTuple{Ks}(Ks)


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
    execute(walk, x, ys...)

Execute a `walk` that recursively calls itself, starting at a node `x` in a Functors tree,
as well as optional associated nodes `ys...` in other Functors trees.
Any custom `walk` function that subtypes [`Functors.AbstractWalk`](@ref) is permitted.
"""
function execute(walk::AbstractWalk, x, ys...)
  # This avoids a performance penalty for recursive constructs in an anonymous function.
  # See Julia issue #47760 and Functors.jl issue #59.
  recurse(xs...) = walk(var"#self#", xs...)
  walk(recurse, x, ys...)
end

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
  re(_map(recurse, func, yfuncs...))
end

struct DefaultWalkWithPath <: AbstractWalk end

function (::DefaultWalkWithPath)(recurse, kp::KeyPath, x, ys...)
  x_children, re = functor(x)
  kps = _map(c -> KeyPath(kp, c), _keys(x_children)) # use _keys and _map to preserve x_children type
  ys_children = map(children, ys)
  re(_map(recurse, kps, x_children, ys_children...))
end


"""
    StructuralWalk()

A structural variant of [`Functors.DefaultWalk`](@ref).
The recursion behavior is identical, but the mapped children are not restructured.

See [`fmapstructure`](@ref) for more information.
"""
struct StructuralWalk <: AbstractWalk end

function (::StructuralWalk)(recurse, x, ys...)
  x_children = children(x)
  ys_children = map(children, ys)
  return _map(recurse, x_children, ys_children...)
end

struct StructuralWalkWithPath <: AbstractWalk end

function (::StructuralWalkWithPath)(recurse, kp::KeyPath, x, ys...)
  x_children = children(x)
  kps = _map(c -> KeyPath(kp, c), _keys(x_children)) # use _keys and _map to preserve x_children type
  ys_children = map(children, ys)
  return _map(recurse, kps, x_children, ys_children...)
end

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

struct ExcludeWalkWithKeyPath{T, F, G} <: AbstractWalk
  walk::T
  fn::F
  exclude::G
end

(walk::ExcludeWalkWithKeyPath)(recurse, kp::KeyPath, x, ys...) =
  walk.exclude(kp, x) ? walk.fn(kp, x, ys...) : walk.walk(recurse, kp, x, ys...)
  

struct NoKeyword end

usecache(::Union{AbstractDict, AbstractSet}, x) =
  isleaf(x) ? anymutable(x) : ismutable(x)
usecache(::Nothing, x) = false

@generated function anymutable(x::T) where {T}
  ismutabletype(T) && return true
  fns = QuoteNode.(filter(n -> fieldtype(T, n) != T, fieldnames(T)))
  subs =  [:(anymutable(getfield(x, $f))) for f in fns]
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
struct CachedWalk{T, S, C <: AbstractDict} <: AbstractWalk
  walk::T
  prune::S
  cache::C
end
CachedWalk(walk; prune = NoKeyword(), cache = IdDict()) =
  CachedWalk(walk, prune, cache)

function (walk::CachedWalk)(recurse, x, ys...)
  should_cache = usecache(walk.cache, x)
  if should_cache && haskey(walk.cache, x)
    return walk.prune isa NoKeyword ? cacheget(walk.cache, x, recurse, x, ys...) : walk.prune
  else
    ret = walk.walk(recurse, x, ys...)
    if should_cache
      walk.cache[x] = ret
    end
    return ret
  end
end

struct CachedWalkWithPath{T, S, C <: AbstractDict} <: AbstractWalk
  walk::T
  prune::S
  cache::C
end

CachedWalkWithPath(walk; prune = NoKeyword(), cache = IdDict()) =
  CachedWalkWithPath(walk, prune, cache)

function (walk::CachedWalkWithPath)(recurse, kp::KeyPath, x, ys...)
  should_cache = usecache(walk.cache, x)
  if should_cache && haskey(walk.cache, x)
    return walk.prune isa NoKeyword ? cacheget(walk.cache, x, recurse, kp, x, ys...) : walk.prune
  else
    ret = walk.walk(recurse, kp, x, ys...)
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
function (walk::CollectWalk)(recurse, x)
  if usecache(walk.cache, x) && (x in walk.cache)
    return walk.output
  end
  # to exclude, we wrap this walk in ExcludeWalk
  usecache(walk.cache, x) && push!(walk.cache, x)
  push!(walk.output, x)
  _map(recurse, children(x))

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

function (walk::IterateWalk)(recurse, x, ys...)
  x_children = children(x)
  ys_children = map(children, ys)
  return Iterators.flatten(_map(recurse, x_children, ys_children...))
end

struct FlattenWalk <: AbstractWalk end

function (walk::FlattenWalk)(recurse, x, ys...)
  x_children = _values(children(x))
  ys_children = map(children, ys)
  res = _map(recurse, x_children, ys_children...)
  return reduce(vcat, _values(res); init = [])
end

