
@functor Base.RefValue

@functor Base.Pair

@functor Base.Generator  # aka Iterators.map

@functor Base.ComposedFunction
@functor Base.Fix1
@functor Base.Fix2
@functor Base.Broadcast.BroadcastFunction

@static if VERSION >= v"1.9"
  @functor Base.Splat
end

@static if VERSION >= v"1.7"
  @functor Base.Returns
end

###
### Array wrappers
###

using LinearAlgebra
# The reason for these is to let W and W' be seen as tied weights in Flux models.
# Can't treat ReshapedArray very well, as its type doesn't include enough details for reconstruction.

functor(::Type{<:Adjoint}, x) = (parent = _adjoint(x),), y -> adjoint(only(y))

_adjoint(x) = adjoint(x)  # _adjoint is the inverse, and also understands more types:
_adjoint(x::NamedTuple{(:parent,)}) = x.parent  # "structural" gradient, and lazy broadcast used by Optimisers:
_adjoint(bc::Broadcast.Broadcasted{S}) where S = Broadcast.Broadcasted{S}(_conjugate(bc.f, adjoint), _adjoint.(bc.args))

functor(::Type{<:Transpose}, x) = (parent = _transpose(x),), y -> transpose(only(y))

_transpose(x) = transpose(x)
_transpose(x::NamedTuple{(:parent,)}) = x.parent
_transpose(bc::Broadcast.Broadcasted{S}) where S = Broadcast.Broadcasted{S}(_conjugate(bc.f, transpose), _transpose.(bc.args))

_conjugate(f::F, ::typeof(identity)) where F = f
_conjugate(f::F, op::Union{typeof(transpose), typeof(adjoint)}) where F = (xs...,) -> op(f(op.(xs)...))

function functor(::Type{<:PermutedDimsArray{T,N,perm,iperm}}, x) where {T,N,perm,iperm}
  (parent = _PermutedDimsArray(x, iperm),), y -> PermutedDimsArray(only(y), perm)
end
function functor(::Type{<:PermutedDimsArray{T,N,perm,iperm}}, x::PermutedDimsArray{Tx,N,perm,iperm}) where {T,Tx,N,perm,iperm}
  (parent = parent(x),), y -> PermutedDimsArray(only(y), perm)  # most common case, avoid wrapping wrice.
end

_PermutedDimsArray(x, iperm) = PermutedDimsArray(x, iperm)
_PermutedDimsArray(x::NamedTuple{(:parent,)}, iperm) = x.parent
_PermutedDimsArray(bc::Broadcast.Broadcasted, iperm) = _PermutedDimsArray(Broadcast.materialize(bc), iperm)

###
### Iterators
###

@functor Iterators.Accumulate
# Count
@functor Iterators.Cycle
@functor Iterators.Drop
@functor Iterators.DropWhile
@functor Iterators.Enumerate
@functor Iterators.Filter
@functor Iterators.Flatten
# IterationCutShort
@functor Iterators.PartitionIterator
@functor Iterators.ProductIterator
@functor Iterators.Repeated
@functor Iterators.Rest
@functor Iterators.Reverse
# Stateful
@functor Iterators.Take
@functor Iterators.TakeWhile
@functor Iterators.Zip
