```@meta
CurrentModule = Functors
```

# API

```@index
Modules = [Functors]
Pages = ["api.md"]
```

## Constructors and helpers

```@docs
Functors.@functor
Functors.@leaf
Functors.functor
Functors.children
Functors.isleaf
Functors.fcollect
Functors.fleaves
```

## Maps

```@docs
Functors.fmap
Functors.fmap_with_path
Functors.fmapstructure
Functors.fmapstructure_with_path
```

## Walks

```@docs
Functors.AbstractWalk
Functors.execute
Functors.DefaultWalk
Functors.StructuralWalk
Functors.ExcludeWalk
Functors.CachedWalk
Functors.CollectWalk
Functors.IterateWalk
```

## KeyPath

```@docs
Functors.KeyPath
Functors.haskeypath
Functors.getkeypath
Functors.setkeypath!
```
