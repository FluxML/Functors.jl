functor(T, x) = (), _ -> x
functor(x) = functor(typeof(x), x)

functor(::Type{<:Tuple}, x) = x, y -> y
functor(::Type{<:NamedTuple}, x) = x, y -> y

functor(::Type{<:AbstractArray}, x) = x, y -> y
functor(::Type{<:AbstractArray{<:Number}}, x) = (), _ -> x

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
  fs == nothing || isexpr(fs, :tuple) || error("@functor T (a, b)")
  fs = fs == nothing ? [] : [:($(map(QuoteNode, fs.args)...),)]
  :(makefunctor(@__MODULE__, $(esc(T)), $(fs...)))
end

macro functor(args...)
  functorm(args...)
end

"""
    isleaf(x)

Return true if `x` has no [`children`](@ref) according to [`functor`](@ref).
"""
isleaf(x) = children(x) === ()

"""
    children(x)

Return the children of `x` as defined by [`functor`](@ref).
Equivalent to `functor(x)[1]`.
"""
children(x) = functor(x)[1]

function fmap1(f, x)
  func, re = functor(x)
  re(map(f, func))
end

# See https://github.com/FluxML/Functors.jl/issues/2 for a discussion regarding the need for
# cache.
function fmap(f, x; cache = IdDict())
  haskey(cache, x) && return cache[x]
  cache[x] = isleaf(x) ? f(x) : fmap1(x -> fmap(f, x, cache = cache), x)
end

"""
    fcollect(x; 
             recurse = (v, vs) -> true, 
             f = (v, vs) -> v)

Traverse `x` recursively through the children defined by [`functor`](@ref)
and return an array containing each node encountered.

Doesn't recurse inside branches rooted at nodes `v` with children `vs` 
for which `recurse(v, vs) == false`.
In such cases, the root `v` is also excluded from the result.
Per default, `recurse` always yields true. 

Optionally, a function `f(v, vs)` taking in input a node and its children 
can  be passed, so that the returned array will contain
`f(v, vs)` instead of `v`. 
"""
function fcollect(x; cache = [], 
                     recurse = (v, vs) -> true, 
                     f = (v, vs) -> v)

  x in cache && return cache
  vs = children(x)
  recurse(x, vs) || return cache
  push!(cache, f(x, vs))
  foreach(y -> fcollect(y; cache=cache, recurse=recurse, f=f), vs)
  return cache
end
