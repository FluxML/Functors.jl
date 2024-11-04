Base.@deprecate fmap(walk::AbstractWalk, f, x, ys...) execute(walk, x, ys...)

function fmap(f, x, ys...; exclude = isleaf,
                           walk = DefaultWalk(),
                           cache = IdDict(),
                           prune = NoKeyword())
  _walk = ExcludeWalk(walk, f, exclude)
  if !isnothing(cache)
    _walk = CachedWalk(_walk, prune, WalkCache(_walk, cache))
  end
  execute(_walk, x, ys...)
end

function fmap_with_path(f, x, ys...; exclude = isleaf,
                                     walk = DefaultWalkWithPath(),
                                     cache = IdDict(),
                                     prune = NoKeyword())
  
  _walk = ExcludeWalkWithKeyPath(walk, f, exclude)
  if !isnothing(cache)
    _walk = CachedWalkWithPath(_walk, prune, WalkCache(_walk, cache))
  end
  return execute(_walk, KeyPath(), x, ys...)
end

fmapstructure(f, x, ys...; kwargs...) = fmap(f, x, ys...; walk = StructuralWalk(), kwargs...)

fmapstructure_with_path(f, x, ys...; kwargs...) = fmap_with_path(f, x, ys...; walk = StructuralWalkWithPath(), kwargs...)

fcollect(x; exclude = v -> false) =
  execute(ExcludeWalk(CollectWalk(), _ -> nothing, exclude), x)

fleaves(x; exclude = isleaf) =
  execute(ExcludeWalk(FlattenWalk(), x -> [x], exclude), x)
