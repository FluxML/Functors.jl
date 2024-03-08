Base.@deprecate fmap(walk::AbstractWalk, f, x, ys...) execute(walk, x, ys...)

function fmap(f, x, ys...; exclude = isleaf,
                           walk = DefaultWalk(),
                           cache = IdDict(),
                           prune = NoKeyword())
  _walk = ExcludeWalk(AnonymousWalk(walk), f, exclude)
  if !isnothing(cache)
    _walk = CachedWalk(_walk, prune, cache)
  end
  execute(_walk, x, ys...)
end

""""
    fmap_with_path(f, x, ys...; exclude = Functors.isleaf, walk = Functors.DefaultWalkWithPath())

Like [`fmap`](@ref), but also passes a `KeyPath` to `f` for each node in the
recursion. The `KeyPath` is a tuple of the indices used to reach the current
node from the root of the recursion. The `KeyPath` is constructed by the
`walk` function, and can be used to reconstruct the path to the current node
from the root of the recursion.

# Examples

```jldoctest
julia> fmap_with_path((x, kp) -> (x, kp), (1, (2, 3)))
(1, ())
(2, (1,))
(3, (2,))
```
"""
function fmap_with_path(f, x, ys...; 
                exclude = isleaf,
                walk = DefaultWalkWithPath())
  
  _walk = ExcludeWalkWithKeyPath(walk, f, exclude)
  return execute(_walk, KeyPath(), x, ys...)
end

fmapstructure(f, x; kwargs...) = fmap(f, x; walk = StructuralWalk(), kwargs...)

fcollect(x; exclude = v -> false) =
  execute(ExcludeWalk(CollectWalk(), _ -> nothing, exclude), x)
