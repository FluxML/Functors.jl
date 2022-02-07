
functor(T, x) = (), _ -> x
functor(x) = functor(typeof(x), x)

functor(::Type{<:Tuple}, x) = x, y -> y
functor(::Type{<:NamedTuple}, x) = x, y -> y

functor(::Type{<:AbstractArray}, x) = x, y -> y
functor(::Type{<:AbstractArray{<:Number}}, x) = (), _ -> x

@static if VERSION >= v"1.6"
  functor(::Type{<:Base.ComposedFunction}, x) = (outer = x.outer, inner = x.inner), y -> Base.ComposedFunction(y.outer, y.inner)
end

function makefunctor(m::Module, T, fs = fieldnames(T))
  yᵢ = 0
  escargs = map(fieldnames(T)) do f
    f in fs ? :(y[$(yᵢ += 1)]) : :(x.$f)
  end
  escfs = [:($f=x.$f) for f in fs]

  @eval m begin
    $Functors.functor(::Type{<:$T}, x) = ($(escfs...),), y -> $T($(escargs...))
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

isleaf(x) = children(x) === ()

children(x) = functor(x)[1]

function _default_walk(f, x)
  func, re = functor(x)
  re(map(f, func))
end

const INIT = Base._InitialValue()  # sentinel value for keyword not supplied

function fmap(f, x; exclude = isleaf, walk = _default_walk, cache = IdDict(), prune = INIT)
  haskey(cache, x) && return prune === INIT ? cache[x] : prune
  cache[x] = exclude(x) ? f(x) : walk(x -> fmap(f, x; exclude, walk, cache, prune), x)
end

###
### Extras
###

fmapstructure(f, x; kwargs...) = fmap(f, x; walk = (f, x) -> map(f, children(x)), kwargs...)

function fcollect(x; output = [], cache = Base.IdSet(), exclude = v -> false)
    # note: we don't have an `OrderedIdSet`, so we use an `IdSet` for the cache
    # (to ensure we get exactly 1 copy of each distinct array), and a usual `Vector`
    # for the results, to preserve traversal order (important downstream!).
    x in cache && return output
    if !exclude(x)
      push!(cache, x)
      push!(output, x)
      foreach(y -> fcollect(y; cache=cache, output=output, exclude=exclude), children(x))
    end
    return output
end

###
### Vararg forms
###

function fmap(f, x, ys...; exclude = isleaf, walk = _default_walk, cache = IdDict(), prune = INIT)
  haskey(cache, x) && return prune === INIT ? cache[x] : prune
  cache[x] = exclude(x) ? f(x, ys...) : walk((xy...,) -> fmap(f, xy...; exclude, walk, cache, prune), x, ys...)
end

function _default_walk(f, x, ys...)
  func, re = functor(x)
  yfuncs = map(y -> functor(typeof(x), y)[1], ys)
  re(map(f, func, yfuncs...))
end

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
