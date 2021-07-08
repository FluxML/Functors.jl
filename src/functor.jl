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

function _default_walk(f, x)
  func, re = functor(x)
  re(map(f, func))
end

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
