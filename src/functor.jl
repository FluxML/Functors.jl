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

function functor_tuple(f, x::Tuple, dx::Tuple)
  map(x, dx) do x, x̄
    _default_walk(f, x, x̄)
  end
end
functor_tuple(f, x, dx) = f(x, dx)
functor_tuple(f, x, ::Nothing) = x

# @functor Chain
# Chain -> func = (layers = (Dense,Dense),), gs -> (layers...)
function _default_walk(f, x, dx)
  func, re = functor(x)
  map(func, dx) do x, x̄
    # functor_tuple(f, x, x̄)
    f(x, x̄)
  end |> re
end

function _default_walk(f, x)
  func, re = functor(x)
  re(map(f, func))
end
_default_walk(f, ::Nothing, ::Nothing) = nothing

"""
    fmap(f, x; exclude = isleaf, walk = Functors._default_walk)

A structure and type preserving `map` that works for all [`functor`](@ref)s.

By default, traverses `x` recursively using [`functor`](@ref)
and transforms every leaf node identified by `exclude` with `f`.

For advanced customization of the traversal behaviour, pass a custom `walk` function of the form `(f', xs) -> ...`.
This function walks (maps) over `xs` calling the continuation `f'` to continue traversal.

# Examples
```jldoctest
julia> struct Foo; x; y; end

julia> @functor Foo

julia> struct Bar; x; end

julia> @functor Bar

julia> m = Foo(Bar([1,2,3]), (4, 5));

julia> fmap(x -> 2x, m)
Foo(Bar([2, 4, 6]), (8, 10))

julia> fmap(string, m)
Foo(Bar("[1, 2, 3]"), ("4", "5"))

julia> fmap(string, m, exclude = v -> v isa Bar)
Foo("Bar([1, 2, 3])", (4, 5))

julia> fmap(x -> 2x, m, walk=(f, x) -> x isa Bar ? x : Functors._default_walk(f, x))
Foo(Bar([1, 2, 3]), (8, 10))
```
"""
function fmap(f, x; exclude = isleaf, walk = _default_walk, cache = IdDict())
  haskey(cache, x) && return cache[x]
  y = exclude(x) ? f(x) : walk(x -> fmap(f, x, exclude = exclude, walk = walk, cache = cache), x)
  cache[x] = y

  return y
end

"""
    fmapstructure(f, x; exclude = isleaf)

Like [`fmap`](@ref), but doesn't preserve the type of custom structs. Instead, it returns a (potentially nested) `NamedTuple`.

Useful for when the output must not contain custom structs.

# Examples
```jldoctest
julia> struct Foo; x; y; end

julia> @functor Foo

julia> m = Foo([1,2,3], (4, 5));

julia> fmapstructure(x -> 2x, m)
(x = [2, 4, 6], y = (8, 10))
```
"""
fmapstructure(f, x; kwargs...) = fmap(f, x; walk = (f, x) -> map(f, children(x)), kwargs...)

"""
    fcollect(x; exclude = v -> false)

Traverse `x` by recursing each child of `x` as defined by [`functor`](@ref)
and collecting the results into a flat array, ordered by a breadth-first
traversal of `x`, respecting the iteration order of `children` calls.

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
Foo(Bar([1, 2, 3]), NoChildren(:a, :b))

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

# Allow gradients and other constructs that match the structure of the functor
# to allow for `map` style computations and return a modified version of the struct.
# This way we can use `fmap` to update the params with their gradients
function fmap(f, x, dx...; cache = IdDict())
  haskey(cache, x) && return cache[x]
  cache[x] = isleaf(x) ? f(x, dx...) : _default_walk((x...) -> fmap(f, x..., cache = cache), x, dx...)
end
