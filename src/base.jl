
@functor Base.RefValue

functor(::Type{<:Base.ComposedFunction}, x) = (outer = x.outer, inner = x.inner), y -> Base.ComposedFunction(y.outer, y.inner)

functor(::Type{<:PermutedDimsArray{T,N,perm}}, x) where {T,N,perm} = (parent = parent(x),), y -> PermutedDimsArray(only(y), perm)

using Base.Iterators

Functors.@functor Iterators.Drop (xs,)
Functors.@functor Iterators.Enumerate
# Functors.@functor Iterators.Flatten
# Functors.@functor Iterators.ProductIterator
# Functors.@functor Iterators.PartitionIterator
Functors.@functor Iterators.Repeated
Functors.@functor Iterators.Reverse
Functors.@functor Iterators.Take (xs,)
Functors.@functor Iterators.Zip

using LinearAlgebra

@functor Adjoint
@functor Transpose
@functor Diagonal
