"""
    Functors.functor(x) = functor(typeof(x), x)

Returns a tuple containing, first, a `NamedTuple` of the children of `x`
(typically its fields), and second, a reconstruction funciton.
This controls the behaviour of [`fmap`](@ref).

Methods should be added to `functor(::Type{T}, x)` for custom types,
usually using the macro [@functor](@ref).
"""
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
  escfs = [:($f = x.$f) for f in fs]

  @eval m begin
    $Functors.functor(::Type{<:$T}, x) = ($(escfs...),), y -> $T($(escargs...))
  end
end

function functorm(T, fs = nothing)
  fs === nothing || Meta.isexpr(fs, :tuple) || error("@functor T (a, b)")
  fs = fs === nothing ? [] : [:($(map(QuoteNode, fs.args)...),)]
  :(makefunctor(@__MODULE__, $(esc(T)), $(fs...)))
end

"""
    @functor T
    @functor T (x,)

Adds methods to [`functor`](@ref) allowing recursion into objects of type `T`,
and reconstruction. Assumes that `T` has a constructor accepting all of its fields,
which is true unless you have provided an inner constructor which does not.

By default all fields of `T` are considered [children](@ref); 
this can be restricted be restructed by providing a tuple of field names.

# Examples
```jldoctest
julia> struct Foo; x; y; end

julia> @functor Foo

julia> Functors.children(Foo(1,2))
(x = 1, y = 2)

julia> _, re = Functors.functor(Foo(1,2));

julia> re((10, 20))
Foo(10, 20)

julia> struct TwoThirds a; b; c; end

julia> @functor TwoThirds (a, c)

julia> ch2, re3 = Functors.functor(TwoThirds(10,20,30));

julia> ch2
(a = 10, c = 30)

julia> re3(("ten", "thirty"))
TwoThirds("ten", 20, "thirty")

julia> fmap(x -> 10x, TwoThirds(Foo(1,2), Foo(3,4), 56))
TwoThirds(Foo(10, 20), Foo(3, 4), 560)
```
"""
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
    Functors.isleaf(x)

Return true if `x` has no [`children`](@ref) according to [`functor`](@ref).

# Examples
```jldoctest
julia> Functors.isleaf(1)
true

julia> Functors.isleaf([2, 3, 4])
true

julia> Functors.isleaf(["five", [6, 7]])
false

julia> Functors.isleaf([])
false

julia> Functors.isleaf((8, 9))
false

julia> Functors.isleaf(())
true
```
"""
isleaf(x) = children(x) === ()

"""
    Functors.children(x)

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
_default_walk(_, ::Nothing, ::Nothing) = nothing

# Side effects only, saves a restructure
function _foreach_walk(f, x)
  foreach(f, children(x))
  return x
end

### WARNING: the following is unstable internal functionality. Use at your own risk!
# Wrapper over an IdDict which only saves values with a stable object identity
struct Cache{K,V}
  inner::IdDict{K,V}
end
Cache() = Cache(IdDict())

iscachesafe(x) = !isbits(x) && ismutable(x)
# Functionally immutable and observe value semantics, but still `ismutable` and not `isbits`
iscachesafe(::Union{String,Symbol}) = false
# For varargs
iscachesafe(xs::Tuple) = all(iscachesafe, xs)
Base.get!(f, c::Cache, x) = iscachesafe(x) ? get!(f, c.inner, x) : f()

# Passthrough used to disable caching (e.g. when passing `cache=false`)
struct NoCache end
Base.get!(f, ::NoCache, _) = f()

# Encapsulates the self-recursive part of a recursive tree reduction (fold).
# This allows calling functions to remove any self-calls or nested callback closures.
struct Fold{F,L,C,W}
  fn::F
  isleaf::L
  cache::C
  walk::W
end
(fld::Fold)(x) = get!(fld.cache, x) do 
  fld.fn(fld.isleaf(x) ? x : fld.walk(fld, x))
end

# Convenience function for working with `Fold`
function fold(f, x; isleaf = isleaf, cache = false, walk = _default_walk)
  if cache === true
    cache = Cache()
  elseif cache === false
    cache = NoCache()
  end
  return Fold(f, isleaf, cache, walk)(x)
end
### end of unstable internal functionality

"""
    fmap(f, x; exclude = Functors.isleaf, walk = Functors._default_walk)

A structure and type preserving `map`.

By default it transforms every leaf node (identified by `exclude`, default [`isleaf`](@ref))
by applying `f`, and otherwise traverses `x` recursively using [`functor`](@ref).

# Examples
```jldoctest
julia> fmap(string, (x=1, y=(2, 3)))
(x = "1", y = ("2", "3"))

julia> nt = (a = [1,2], b = [23, (45,), (x=6//7, y=())], c = [8,9]);

julia> fmap(println, nt)
[1, 2]
23
45
6//7
()
[8, 9]
(a = nothing, b = Any[nothing, (nothing,), (x = nothing, y = nothing)], c = nothing)

julia> fmap(println, nt; exclude = x -> x isa Array)
[1, 2]
Any[23, (45,), (x = 6//7, y = ())]
[8, 9]
(a = nothing, b = nothing, c = nothing)

julia> twice = [1, 2];

julia> fmap(println, (i = twice, ii = 34, iii = [5, 6], iv = (twice, 34), v = 34.0))
[1, 2]
34
[5, 6]
34.0
(i = nothing, ii = nothing, iii = nothing, iv = (nothing, nothing), v = nothing)
```

If the same node (same according to `===`) appears more than once,
it will only be handled once, and only be transformed once with `f`.
Thus the result will also have this relationship.

By default, `Tuple`s, `NamedTuple`s, and some other container-like types in Base have
children to recurse into. Arrays of numbers do not.
To enable recursion into new types, you must provide a method of [`functor`](@ref),
which can be done using the macro [`@functor`](@ref):

```jldoctest withfoo
julia> struct Foo; x; y; end

julia> @functor Foo

julia> struct Bar; x; end

julia> @functor Bar

julia> m = Foo(Bar([1,2,3]), (4, 5, Bar(Foo(6, 7))));

julia> fmap(x -> 10x, m)
Foo(Bar([10, 20, 30]), (40, 50, Bar(Foo(60, 70))))

julia> fmap(string, m)
Foo(Bar("[1, 2, 3]"), ("4", "5", Bar(Foo("6", "7"))))

julia> fmap(string, m, exclude = v -> v isa Bar)
Foo("Bar([1, 2, 3])", (4, 5, "Bar(Foo(6, 7))"))
```

To recurse into custom types without reconstructing them afterwards,
use [`fmapstructure`](@ref).

For advanced customization of the traversal behaviour, pass a custom `walk` function of the form `(f', xs) -> ...`.
This function walks (maps) over `xs` calling the continuation `f'` to continue traversal.

```jldoctest withfoo
julia> fmap(x -> 10x, m, walk=(f, x) -> x isa Bar ? x : Functors._default_walk(f, x))
Foo(Bar([1, 2, 3]), (40, 50, Bar(Foo(6, 7))))
```
"""
function fmap(f, x; exclude = isleaf, walk = _default_walk, cache = IdDict())
  return fold(x; cache, walk, isleaf = exclude) do node
    !exclude(node) && return node
    return f(node)
  end
end

"""
    fmapstructure(f, x; exclude = isleaf)

Like [`fmap`](@ref), but doesn't preserve the type of custom structs.
Instead, it returns a `NamedTuple` (or a `Tuple`, or an array),
or a nested set of these.

Useful for when the output must not contain custom structs.

# Examples
```jldoctest
julia> struct Foo; x; y; end

julia> @functor Foo

julia> m = Foo([1,2,3], [4, (5, 6), Foo(7, 8)]);

julia> fmapstructure(x -> 2x, m)
(x = [2, 4, 6], y = Any[8, (10, 12), (x = 14, y = 16)])

julia> fmapstructure(println, m)
[1, 2, 3]
4
5
6
7
8
(x = nothing, y = Any[nothing, (nothing, nothing), (x = nothing, y = nothing)])
```
"""
fmapstructure(f, x; kwargs...) = fmap(f, x; walk = (f, x) -> map(f, children(x)), kwargs...)

"""
    fcollect(x; exclude = v -> false)

Traverse `x` by recursing each child of `x` as defined by [`functor`](@ref)
and collecting the results into a flat array, ordered by a depth-first,
post-order traversal of `x` that respects the iteration order of `children` calls.

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
 [1, 2, 3]
 Bar([1, 2, 3])
 NoChildren(:a, :b)
 Foo(Bar([1, 2, 3]), NoChildren(:a, :b))

julia> fcollect(m, exclude = v -> v isa Bar)
2-element Vector{Any}:
 NoChildren(:a, :b)
 Foo(Bar([1, 2, 3]), NoChildren(:a, :b))

julia> fcollect(m, exclude = v -> Functors.isleaf(v))
2-element Vector{Any}:
 Bar([1, 2, 3])
 Foo(Bar([1, 2, 3]), NoChildren(:a, :b))
```
"""
function fcollect(x; output = [], cache = Base.IdDict(), exclude = v -> false)
  fold(x; cache, isleaf = exclude, walk = _foreach_walk) do node
    exclude(node) || push!(output, node);  # always return nothing
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
