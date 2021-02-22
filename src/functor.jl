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
function fmap(f, x; predicate = x -> false, cache = IdDict())
  haskey(cache, x) && return cache[x]
  cache[x] = (predicate(x) || isleaf(x)) ? f(x) : fmap1(x -> fmap(f, x, cache = cache), x)
end

"""
    fcollect(x; exclude = v -> false)

Traverse `x` by recursing each child of `x` as defined by [`functor`](@ref)
and collecting the results into a flat array.

Doesn't recurse inside branches rooted at nodes `v`
for which `exclude(v) == true`.
In such cases, the root `v` is also excluded from the result.
By default, `exclude` always yields `false`. 

See also [`children`](@ref).

# Examples

```jldoctest
julia> struct Foo; x; y; end

julia> @functor Foo

julia> struct Bar; x; end

julia> @functor Bar

julia> struct NoChildren; x; y; end 

julia> m = Foo(Bar([1,2,3]), NoChildren(:a, :b))

julia> fcollect(m)
4-element Vector{Any}:
 Foo(Bar([1, 2, 3]), NoChildren(:a, :b))
 Bar([1, 2, 3])
 [1, 2, 3]
 NoChildren(:a, :b)

julia> fcollect(m, exclude = v -> v isa Bar)
2-element Vector{Any}:
 Foo(Bar([1, 2, 3]), NoChildren(:a, :b))
 NoChildren(:a, :b)
 
julia> fcollect(m, exclude = v -> Functors.isleaf(v))
2-element Vector{Any}:
 Foo(Bar([1, 2, 3]), NoChildren(:a, :b))
 Bar([1, 2, 3])
```
"""
function fcollect(x; cache = [], exclude = v -> false)
  x in cache && return cache
  if !exclude(x)
    push!(cache, x)
    foreach(y -> fcollect(y; cache = cache, exclude = exclude), children(x))
  end
  return cache
end
