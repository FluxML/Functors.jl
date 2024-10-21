function functor end

const NoChildren = Tuple{}

"""
    @leaf T

Define [`functor`](@ref) for the type `T` so that  `isleaf(x::T) == true`.
"""
macro leaf(T)
  :($Functors.functor(::Type{<:$(esc(T))}, x) = ($Functors.NoChildren(), _ -> x))
end

# Default functor
function functor(T, x)
  names = fieldnames(T)
  if isempty(names)
    return NoChildren(), _ -> x
  end
  S = constructorof(T) # remove parameters from parametric types and support anonymous functions
  vals = ntuple(i -> getfield(x, names[i]), length(names))
  return NamedTuple{names}(vals), y -> S(y...)
end

functor(x) = functor(typeof(x), x)

functor(::Type{<:Tuple}, x) = x, identity
functor(::Type{<:NamedTuple{L}}, x) where L = NamedTuple{L}(map(s -> getproperty(x, s), L)), identity
functor(::Type{<:Dict}, x) = Dict(k => x[k] for k in keys(x)), identity

functor(::Type{<:AbstractArray}, x) = x, identity
@leaf AbstractArray{<:Number}

function makefunctor(m::Module, T, fs = fieldnames(T))
  fidx = Ref(0)
  escargs = map(fieldnames(T)) do f
    f in fs ? :(y[$(fidx[] += 1)]) : :(x.$f)
  end
  escargs_nt = map(fieldnames(T)) do f
    f in fs ? :(y[$(Meta.quot(f))]) : :(x.$f)
  end
  escfs = [:($f=x.$f) for f in fs]
  
  @eval m begin
    function $Functors.functor(::Type{<:$T}, x)
      reconstruct(y) = $T($(escargs...))
      reconstruct(y::NamedTuple) = $T($(escargs_nt...))
      return (;$(escfs...)), reconstruct
    end
  end
end

function functorm(T, fs = nothing)
  fs === nothing || Meta.isexpr(fs, :tuple) || error("@functor T (a, b)")
  fs = fs === nothing ? [] : [:($(map(QuoteNode, fs.args)...),)]
  :(makefunctor(@__MODULE__, $(esc(T)), $(fs...)))
end

macro functor(args...)
  functorm(args...)
end

isleaf(@nospecialize(x)) = children(x) === NoChildren()

children(x) = functor(x)[1]

###
### FlexibleFunctors.jl
###

function makeflexiblefunctor(m::Module, T, pfield)
  pfield = QuoteNode(pfield)
  @eval m begin
    function $Functors.functor(::Type{<:$T}, x)
      pfields = getproperty(x, $pfield)
      function re(y)
        all_args = map(fn -> getproperty(fn in pfields ? y : x, fn), fieldnames($T))
        return $T(all_args...)
      end
      func = NamedTuple{pfields}(map(p -> getproperty(x, p), pfields))
      return func, re
    end
  end
end

function flexiblefunctorm(T, pfield = :params)
  pfield isa Symbol || error("@flexiblefunctor T param_field")
  pfield = QuoteNode(pfield)
  :(makeflexiblefunctor(@__MODULE__, $(esc(T)), $(esc(pfield))))
end

macro flexiblefunctor(args...)
  flexiblefunctorm(args...)
end

###
### Compat
###

if VERSION < v"1.7"
  # Function in 1.7 checks t.name.flags & 0x2 == 0x2,
  # but for 1.6 this seems to work instead:
  ismutabletype(@nospecialize t) = t.mutable
end
