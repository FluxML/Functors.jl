module Functors
using Compat: @compat
using ConstructionBase: constructorof
using LinearAlgebra
using Random: AbstractRNG

export @leaf, @functor, @flexiblefunctor,
       fmap, fmapstructure, fcollect, execute, fleaves,
       fmap_with_path, fmapstructure_with_path,
       KeyPath, getkeypath, haskeypath, setkeypath!

@compat(public, (isleaf, children, functor))

include("functor.jl")
include("keypath.jl")
include("walks.jl")
include("cache.jl")
include("maps.jl")
include("base.jl")

###
### Docstrings for basic functionality
###


"""
    functor(x)
    functor(typeof(x), x)

Returns a tuple containing, first, a `NamedTuple` of the children of `x`
(typically its fields), and second, a reconstruction function.
This controls the behaviour of [`fmap`](@ref).

Methods should be added to `functor(::Type{T}, x)` for custom types,
usually using the macro [`@functor`](@ref).
"""
functor

@doc """
    @functor T
    @functor T (x,)

Adds methods to [`functor`](@ref Functors.functor) allowing recursion into objects of type `T`,
and reconstruction. Assumes that `T` has a constructor accepting all of its fields,
which is true unless you have provided an inner constructor which does not.

By default all fields of `T` are considered [`children`](@ref); 
this can be restricted be restructed by providing a tuple of field names.

# Examples
```jldoctest
julia> struct Foo; x; y; end

julia> Functors.children(Foo(1,2))
(x = 1, y = 2)

julia> _, re = Functors.functor(Foo(1,2));

julia> re((10, 20))
Foo(10, 20)

julia> @functor Foo # same as before, nothing changes

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
var"@functor"

"""
    isleaf(x)

Return true if `x` has no [`children`](@ref Functors.children) according to [`functor`](@ref Functors.functor).

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
isleaf

"""
    children(x)

Return the children of `x` as defined by [`functor`](@ref Functors.functor).
Equivalent to `functor(x)[1]`.
"""
children

"""
    fmap(f, x, ys...; exclude = Functors.isleaf, walk = Functors.DefaultWalk(), [prune])

A structure and type preserving `map`.

By default it transforms every leaf node (identified by `exclude`, default [`isleaf`](@ref Functors.isleaf))
by applying `f`, and otherwise traverses `x` recursively using [`functor`](@ref Functors.functor).
Optionally, it may also be associated with objects `ys` with the same tree structure.
In that case, `f` is applied to the corresponding leaf nodes in `x` and `ys`.

See also [`fmap_with_path`](@ref) and [`fmapstructure`](@ref).

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

julia> twice = [1, 2];  # println only acts once on this

julia> fmap(println, (i = twice, ii = 34, iii = [5, 6], iv = (twice, 34), v = 34.0))
[1, 2]
34
[5, 6]
34
34.0
(i = nothing, ii = nothing, iii = nothing, iv = (nothing, nothing), v = nothing)

julia> d1 = Dict("x" => [1,2], "y" => 3);

julia> d2 = Dict("x" => [4,5], "y" => 6, "z" => "an_extra_value");

julia> fmap(+, d1, d2) == Dict("x" => [5, 7], "y" => 9) # Note that "z" is ignored
true
```

Mutable objects which appear more than once are only handled once (by caching `f(x)` in an `IdDict`).
Thus the relationship `x.i === x.iv[1]` will be preserved.
An immutable object which appears twice is not stored in the cache, thus `f(34)` will be called twice,
and the results will agree only if `f` is pure.

By default, almost all container-like types have children to recurse into. 
Arrays of numbers do not.

To opt out of recursion for custom types use [`@leaf`](@ref) or pass a custom `exclude` function.

```jldoctest withfoo
julia> struct Foo; x; y; end

julia> struct Bar; x; end

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

For advanced customization of the traversal behaviour,
pass a custom `walk` function that subtypes [`Functors.AbstractWalk`](@ref).
The call `fmap(f, x, ys...; walk = mywalk)` will wrap `mywalk` in
[`ExcludeWalk`](@ref) then [`CachedWalk`](@ref).
Here, [`ExcludeWalk`](@ref) is responsible for applying `f` at excluded nodes.
For a low-level interface for executing a user-constructed walk, see [`execute`](@ref).
```jldoctest withfoo
julia> struct MyWalk <: Functors.AbstractWalk end

julia> (::MyWalk)(recurse, x) = x isa Bar ? "hello" :
                                            Functors.DefaultWalk()(recurse, x)

julia> fmap(x -> 10x, m; walk = MyWalk())
Foo("hello", (40, 50, "hello"))
```

The behaviour when the same node appears twice can be altered by giving a value
to the `prune` keyword, which is then used in place of all but the first:

```jldoctest
julia> twice = [1, 2];

julia> fmap(float, (x = twice, y = [1,2], z = twice); prune = missing)
(x = [1.0, 2.0], y = [1.0, 2.0], z = missing)
```
"""
fmap


###
### Extras
###


"""
    fmapstructure(f, x, ys...; exclude = isleaf, [prune])

Like [`fmap`](@ref), but doesn't preserve the type of custom structs.
Instead, it returns a `NamedTuple` (or a `Tuple`, or an array),
or a nested set of these.

Useful for when the output must not contain custom structs.

See also [`fmap`](@ref) and [`fmapstructure_with_path`](@ref).

# Examples
```jldoctest
julia> struct Foo; x; y; end

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
fmapstructure

"""
    fcollect(x; exclude = v -> false)

Traverse `x` by recursing each child of `x` as defined by [`functor`](@ref Functors.functor)
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

julia> struct Bar; x; end

julia> struct TypeWithNoChildren; x; y; end

julia> @leaf TypeWithNoChildren

julia> m = Foo(Bar([1,2,3]), TypeWithNoChildren(:a, :b))
Foo(Bar([1, 2, 3]), TypeWithNoChildren(:a, :b))

julia> fcollect(m)
4-element Vector{Any}:
 Foo(Bar([1, 2, 3]), TypeWithNoChildren(:a, :b))
 Bar([1, 2, 3])
 [1, 2, 3]
 TypeWithNoChildren(:a, :b)

julia> fcollect(m, exclude = v -> v isa Bar)
2-element Vector{Any}:
 Foo(Bar([1, 2, 3]), TypeWithNoChildren(:a, :b))
 TypeWithNoChildren(:a, :b)

julia> fcollect(m, exclude = v -> Functors.isleaf(v))
2-element Vector{Any}:
 Foo(Bar([1, 2, 3]), TypeWithNoChildren(:a, :b))
 Bar([1, 2, 3])
```
"""
fcollect


"""
    fmap_with_path(f, x, ys...; exclude = isleaf, walk = DefaultWalkWithPath(), [prune])

Like [`fmap`](@ref), but also passes a [`KeyPath`](@ref Functors.KeyPath) to `f` for each node in the
recursion. The `KeyPath` is a tuple of the indices used to reach the current
node from the root of the recursion. The `KeyPath` is constructed by the
`walk` function, and can be used to reconstruct the path to the current node
from the root of the recursion.

`f` has to accept two arguments: the associated `KeyPath` and the value of the current node.

`exclude` also receives the `KeyPath` as its first argument and a node as its second.
It should return `true` if the recursion should not continue on its children and `f` applied to it.

`prune` is used to control the behaviour when the same node appears twice, see [`fmap`](@ref)
for more information.

# Examples

```jldoctest
julia> x = ([1, 2, 3], 4, (a=5, b=Dict("A"=>6, "B"=>7), c=Dict("C"=>8, "D"=>9)));

julia> exclude(kp, x) = kp == KeyPath(3, :c) || Functors.isleaf(x);

julia> fmap_with_path((kp, x) -> x isa Dict ? nothing : x.^2, x; exclude = exclude)
([1, 4, 9], 16, (a = 25, b = Dict("B" => 49, "A" => 36), c = nothing))
```
"""
fmap_with_path

"""
    fmapstructure_with_path(f, x, ys...; [exclude, prune])

Like [`fmap_with_path`](@ref), but doesn't preserve the type of custom structs.
Instead, it returns a named tuple, a tuple, an array, a dict, 
or a nested set of these.

See also [`fmapstructure`](@ref).
"""
fmapstructure_with_path


"""
    fleaves(x; exclude = isleaf)

Traverse `x` by recursing each child of `x` as defined by [`functor`](@ref Functors.functor)
and collecting the leaves into a flat array, 
ordered by a breadth-first traversal of `x`, respecting the iteration order of `children` calls.

The `exclude` function is used to determine whether to recurse into a node, therefore
identifying the leaves as the nodes for which `exclude` returns `true`.

See also [`fcollect`](@ref) for a similar function that collects all nodes instead.

# Examples

```jldoctest
julia> struct Bar; x; end

julia> struct TypeWithNoChildren; x; y; end

julia> @leaf TypeWithNoChildren

julia> m = (a = Bar([1,2,3]), b = TypeWithNoChildren(4, 5));

julia> fleaves(m)
2-element Vector{Any}:
 [1, 2, 3]
 TypeWithNoChildren(4, 5)
```
"""
fleaves

end # module

