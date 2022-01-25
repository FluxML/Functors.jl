"""
    Functors.functor(x) = functor(typeof(x), x)

Returns a tuple containing, first, a `NamedTuple` of the children of `x`
(typically its fields), and second, a reconstruction function.
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
_default_walk(f, ::Nothing, ::Nothing) = nothing

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
34
34.0
(i = nothing, ii = nothing, iii = nothing, iv = (nothing, nothing), v = nothing)
```

If the same node (same according to `===`, and not `isbits`) appears more than once,
it will only be transformed once with `f`, or only recursively traversed once.
Thus the result will also have this relationship.

By default, `Tuple`s, `NamedTuple`s, and some other container-like types in Base have
children to recurse into. `Array`s of numbers do not.
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

There are two more obscure keywords to describe:

* `pointers = false` will disable the checking for arrays which aren't `===` but share the same
  storage, such as `reshape`s. By default (`pointers = Set{UInt}`) these will give an error.

* `prune = false` is the default, repeated nodes in the input are preserved. Changing this to
  `prune = nothing` will instead replace all but the first occurance with `nothing`.
  (It is used to avoid double-counting the gradients of shared weights.)
"""
function fmap(f, x; exclude = isleaf, walk = _default_walk, cache = IdDict(), pointers = Set{UInt}(), prune = false)
  if !isbits(x)
    haskey(cache, x) && return prune === false ? cache[x] : prune
    pointercheck(pointers, x)
  end
  y = exclude(x) ? f(x) : walk(x -> fmap(f, x; exclude, walk, cache, pointers, prune), x)
  if !isbits(x)
    cache[x] = y
  end
  return y
end

function pointercheck(seen::Set, x::DenseArray)
  ptr = UInt(pointer(x))
  ptr in seen && throw(ArgumentError(
    """Functors.jl allows the same object to appear at several nodes, but not
    `A !== B` sharing the same pointer, as created for example by `reshape`."""))
  push!(seen, ptr)
end
pointercheck(_, _) = nothing

"""
    fmapstructure(f, x; exclude = isleaf)

Like [`fmap`](@ref), but doesn't preserve the type of custom structs.
Instead, it returns a `NamedTuple` (or a `Tuple`, or an array),
or a nested set of these.

Useful for when the output must not contain custom structs,
or as a Functors.jl version of `foreach` where its output will be discarded,
but may not be accepted by the type constructors.

# Examples
```jldoctest
julia> struct FooVec; x::Vector; y::Vector; end

julia> @functor FooVec

julia> m = FooVec([1,2,3], [missing, (4, 5), FooVec([6, 7], Int[])]);

julia> fmapstructure(x -> 2x, m)
(x = [2, 4, 6], y = Any[missing, (8, 10), (x = [12, 14], y = Int64[])])

julia> fmapstructure(println, m; exclude=Functors.isnumeric)
[1, 2, 3]
[6, 7]
Int64[]
(x = nothing, y = Any[(), ((), ()), (x = nothing, y = nothing)])

julia> try fmap(println, m; exclude=Functors.isnumeric) catch e typeof(e) end
[1, 2, 3]
[6, 7]
Int64[]
MethodError
```
"""
fmapstructure(f, x; kwargs...) = fmap(f, x; walk = _structure_walk, kwargs...)

function _structure_walk(f, x)
  func, _ = functor(x)
  map(f, func)
end

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
