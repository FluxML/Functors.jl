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

fmapstructure(f, x; kwargs...) = fmap(f, x; walk = StructuralWalk(), kwargs...)

fcollect(x; exclude = v -> false) =
  execute(ExcludeWalk(CollectWalk(), _ -> nothing, exclude), x)

fleaves(x; exclude = isleaf) =
  execute(ExcludeWalk(FlattenWalk(), x -> [x], exclude), x)
