module Functors

export @functor, @flexiblefunctor, fmap, fmapstructure, fcollect

include("functor.jl")
include("base.jl")


###
### Docstrings for basic functionality
###


"""
    Functors.functor(x) = functor(typeof(x), x)

Returns a tuple containing, first, a `NamedTuple` of the children of `x`
(typically its fields), and second, a reconstruction funciton.
This controls the behaviour of [`fmap`](@ref).

Methods should be added to `functor(::Type{T}, x)` for custom types,
usually using the macro [@functor](@ref).
"""
functor

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
var"@functor"

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
isleaf

"""
    Functors.children(x)

Return the children of `x` as defined by [`functor`](@ref).
Equivalent to `functor(x)[1]`.
"""
children

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
fmap


###
### Extras
###


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
fmapstructure

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
fcollect

end # module
