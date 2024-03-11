```@meta
CurrentModule = Functors
```

# Basic Layers

## Index

```@index
Modules = [Functors]
Pages = ["api.md"]
```

## Docs

### Constructors and helpers

```@docs
Functors.@functor
Functors.@leaf
Functors.functor
Functors.children
Functors.isleaf
Functors.fcollect
Functors.fleaves
```

### Maps

```@docs
Functors.fmap
Functors.fmap_with_path
Functors.fmapstructure
Functors.fmapstructure_with_path
```

### Walks

```@docs
Functors.AbstractWalk
Functors.execute
Functors.DefaultWalk
Functors.StructuralWalk
Functors.ExcludeWalk
Functors.CachedWalk
Functors.CollectWalk
Functors.AnonymousWalk
Functors.IterateWalk
```

### KeyPath

```@docs
Functors.KeyPath
```
