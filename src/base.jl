###
### Opt-Out
###

@leaf Type
@leaf Number
@leaf AbstractArray{<:Number}
@leaf AbstractString
@leaf AbstractChar
@leaf AbstractMatch
@leaf AbstractPattern
@leaf AbstractRNG

###
### Fast Paths for common types
###

functor(::Type{<:Tuple}, x) = x, identity
functor(::Type{<:NamedTuple{L}}, x) where L = NamedTuple{L}(map(s -> getproperty(x, s), L)), identity
functor(::Type{<:Dict}, x) = Dict(k => x[k] for k in keys(x)), identity
functor(::Type{<:AbstractArray}, x) = x, identity

# This may be a reasonable default for AbstractDict
# but is not guaranteed to be correct for all dict subtypes
function functor(::Type{D}, x) where {D<:AbstractDict}
  return constructorof(D)([k => x[k] for k in keys(x)]...), identity
end

### 
### Base Types requiring special handling
###

@static if VERSION >= v"1.12-DEV"
  functor(::Type{<:Base.Fix{N}}, x) where N = (; x.f, x.x), y -> Base.Fix{N}(y.f, y.x)
end


###
### Array wrappers
###

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
  (parent = parent(x),), y -> PermutedDimsArray(only(y), perm)  # most common case, avoid wrapping twice.
end

_PermutedDimsArray(x, iperm) = PermutedDimsArray(x, iperm)
_PermutedDimsArray(x::NamedTuple{(:parent,)}, iperm) = x.parent
_PermutedDimsArray(bc::Broadcast.Broadcasted, iperm) = _PermutedDimsArray(Broadcast.materialize(bc), iperm)
