
@functor Base.RefValue

functor(::Type{<:Base.ComposedFunction}, x) = (outer = x.outer, inner = x.inner), y -> Base.ComposedFunction(y.outer, y.inner)

using Base.Iterators
# The reason for these is that calling `Iterators.cycle(data) |> gpu` in Flux should just work.

@functor Iterators.Cycle
@functor Iterators.Drop (xs,)
@functor Iterators.Enumerate
@functor Iterators.Flatten
@functor Iterators.ProductIterator
@functor Iterators.PartitionIterator (c,)
@functor Iterators.Repeated
@functor Iterators.Reverse
@functor Iterators.Take (xs,)
@functor Iterators.Zip

using LinearAlgebra
# The reason for these is to let W and W' be seen as tied weights in Flux models.
# But the problem is that the gradient of W' may be a Matrix, so the trees don't match,
# so we will call `lazywrap` instead of walking:

functor(::Type{<:Adjoint}, x) = (parent = parent(x),), y -> adjoint(only(y))
lazywrap(x::Adjoint) = parent(x), adjoint

functor(::Type{<:Transpose}, x) = (parent = parent(x),), y -> transpose(only(y))
lazywrap(x::Transpose) = parent(x), transpose

functor(::Type{<:Base.ReshapedArray}, x) = (parent = parent(x),), y -> Base.ReshapedArray(only(y), x.dims, x.mi)
lazywrap(x::Base.ReshapedArray) = parent(x), dx -> reshape(dx, axes(parent(x)))

functor(::Type{<:PermutedDimsArray{T,N,perm}}, x) where {T,N,perm} = (parent = parent(x),), y -> PermutedDimsArray(only(y), perm)
lazywrap(x::PermutedDimsArray{T,N,perm,iperm}) where {T,N,perm,iperm} = parent(x), dx -> PermutedDimsArray(dx, iperm)

# And this is how we will know when not to do this:
lazywrap(_) = nothing
