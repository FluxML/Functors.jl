fmap(walk::AbstractWalk, f, x, ys...) = walk((xs...) -> fmap(walk, f, xs...), x, ys...)

function fmap(f, x, ys...; exclude = isleaf,
                           walk = DefaultWalk(),
                           cache = IdDict(),
                           prune = NoKeyword())
  _walk = ExcludeWalk(AnonymousWalk(walk), f, exclude)
  if !isnothing(cache)
    _walk = CachedWalk(_walk, prune, cache)
  end
  fmap(_walk, f, x, ys...)
end

fmapstructure(f, x; kwargs...) = fmap(f, x; walk = StructuralWalk(), kwargs...)
fmapstructure(x; kwargs...) = fmapstructure(identity, x; kwargs...)

fcollect(x; exclude = v -> false) =
  fmap(ExcludeWalk(CollectWalk(), _ -> nothing, exclude), _ -> nothing, x)
