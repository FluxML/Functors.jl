Base.@deprecate fmap(walk::AbstractWalk, f, x, ys...) walk(x, ys...)

function fmap(f, x, ys...; exclude = isleaf,
                           walk = DefaultWalk(),
                           cache = IdDict(),
                           prune = NoKeyword())
  _walk = ExcludeWalk(AnonymousWalk(walk), f, exclude)
  if !isnothing(cache)
    _walk = CachedWalk(_walk, prune, cache)
  end
  _walk(x, ys...)
end

fmapstructure(f, x; kwargs...) = fmap(f, x; walk = StructuralWalk(), kwargs...)

function fcollect(x; exclude = v -> false)
  walk = ExcludeWalk(CollectWalk(), _ -> nothing, exclude)
  walk(x)
end
