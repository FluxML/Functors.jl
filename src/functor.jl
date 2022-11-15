
functor(T, x) = (), Returns(x)
functor(x) = functor(typeof(x), x)

functor(::Type{<:Tuple}, x) = x, identity
functor(::Type{<:NamedTuple{L}}, x) where L = NamedTuple{L}(map(s -> getfield(x, s), L)), identity

functor(::Type{<:AbstractArray}, x) = x, identity
functor(::Type{<:AbstractArray{<:Number}}, x) = (), Returns(x)

function makefunctor(m::Module, T, fs = fieldnames(T))
  yᵢ = 0
  escargs = map(fieldnames(T)) do f
    f in fs ? :(y[$(yᵢ += 1)]) : :(x.$f)
  end
  escfs = [:($f = getfield(x, $(QuoteNode(f)))) for f in fs]

  @eval m begin
    $Functors.functor(::Type{<:$T}, x) = (;$(escfs...)), y -> $T($(escargs...))
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

isleaf(@nospecialize(x)) = children(x) === ()

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

# https://github.com/JuliaLang/julia/pull/39794
if VERSION < v"1.7.0-DEV.793"
    struct Returns{V} <: Function
        value::V
        Returns{V}(value) where {V} = new{V}(value)
        Returns(value) = new{Core.Typeof(value)}(value)
    end

    (obj::Returns)(args...; kw...) = obj.value
    function Base.show(io::IO, obj::Returns)
        show(io, typeof(obj))
        print(io, "(")
        show(io, obj.value)
        print(io, ")")
    end
end
