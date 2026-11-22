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

## Reading children without specializing

```@docs
Functors.nospecialize_children
Functors.nospecialize_isleaf
Functors.ChildList
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
Functors.FlattenWalk
```

## KeyPath

```@docs
Functors.KeyPath
Functors.haskeypath
Functors.getkeypath
Functors.setkeypath!
```
