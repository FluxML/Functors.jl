var documenterSearchIndex = {"docs":
[{"location":"api/","page":"API","title":"API","text":"Functors.fmap\nFunctors.@functor","category":"page"},{"location":"api/#Functors.fmap","page":"API","title":"Functors.fmap","text":"fmap(f, x, ys...; exclude = Functors.isleaf, walk = Functors.DefaultWalk()[, prune])\nfmap(walk, f, x, ys...)\n\nA structure and type preserving map.\n\nBy default it transforms every leaf node (identified by exclude, default isleaf) by applying f, and otherwise traverses x recursively using functor.\n\nExamples\n\njulia> fmap(string, (x=1, y=(2, 3)))\n(x = \"1\", y = (\"2\", \"3\"))\n\njulia> nt = (a = [1,2], b = [23, (45,), (x=6//7, y=())], c = [8,9]);\n\njulia> fmap(println, nt)\n[1, 2]\n23\n45\n6//7\n()\n[8, 9]\n(a = nothing, b = Any[nothing, (nothing,), (x = nothing, y = nothing)], c = nothing)\n\njulia> fmap(println, nt; exclude = x -> x isa Array)\n[1, 2]\nAny[23, (45,), (x = 6//7, y = ())]\n[8, 9]\n(a = nothing, b = nothing, c = nothing)\n\njulia> twice = [1, 2];  # println only acts once on this\n\njulia> fmap(println, (i = twice, ii = 34, iii = [5, 6], iv = (twice, 34), v = 34.0))\n[1, 2]\n34\n[5, 6]\n34\n34.0\n(i = nothing, ii = nothing, iii = nothing, iv = (nothing, nothing), v = nothing)\n\nMutable objects which appear more than once are only handled once (by caching f(x) in an IdDict). Thus the relationship x.i === x.iv[1] will be preserved. An immutable object which appears twice is not stored in the cache, thus f(34) will be called twice, and the results will agree only if f is pure.\n\nBy default, Tuples, NamedTuples, and some other container-like types in Base have children to recurse into. Arrays of numbers do not. To enable recursion into new types, you must provide a method of functor, which can be done using the macro @functor:\n\njulia> struct Foo; x; y; end\n\njulia> @functor Foo\n\njulia> struct Bar; x; end\n\njulia> @functor Bar\n\njulia> m = Foo(Bar([1,2,3]), (4, 5, Bar(Foo(6, 7))));\n\njulia> fmap(x -> 10x, m)\nFoo(Bar([10, 20, 30]), (40, 50, Bar(Foo(60, 70))))\n\njulia> fmap(string, m)\nFoo(Bar(\"[1, 2, 3]\"), (\"4\", \"5\", Bar(Foo(\"6\", \"7\"))))\n\njulia> fmap(string, m, exclude = v -> v isa Bar)\nFoo(\"Bar([1, 2, 3])\", (4, 5, \"Bar(Foo(6, 7))\"))\n\nTo recurse into custom types without reconstructing them afterwards, use fmapstructure.\n\nFor advanced customization of the traversal behaviour, pass a custom walk function that subtypes Functors.AbstractWalk. The form fmap(walk, f, x, ys...) can be called for custom walks. The simpler form fmap(f, x, ys...; walk = mywalk) will wrap mywalk in ExcludeWalk then CachedWalk.\n\njulia> struct MyWalk <: Functors.AbstractWalk end\n\njulia> (::MyWalk)(recurse, x) = x isa Bar ? \"hello\" :\n                                            Functors.DefaultWalk()(recurse, x)\n\njulia> fmap(x -> 10x, m; walk = MyWalk())\nFoo(\"hello\", (40, 50, \"hello\"))\n\njulia> fmap(MyWalk(), x -> 10x, m)\nFoo(\"hello\", (4, 5, \"hello\"))\n\nThe behaviour when the same node appears twice can be altered by giving a value to the prune keyword, which is then used in place of all but the first:\n\njulia> twice = [1, 2];\n\njulia> fmap(float, (x = twice, y = [1,2], z = twice); prune = missing)\n(x = [1.0, 2.0], y = [1.0, 2.0], z = missing)\n\n\n\n\n\n","category":"function"},{"location":"api/#Functors.@functor","page":"API","title":"Functors.@functor","text":"@functor T\n@functor T (x,)\n\nAdds methods to functor allowing recursion into objects of type T, and reconstruction. Assumes that T has a constructor accepting all of its fields, which is true unless you have provided an inner constructor which does not.\n\nBy default all fields of T are considered children;  this can be restricted be restructed by providing a tuple of field names.\n\nExamples\n\njulia> struct Foo; x; y; end\n\njulia> @functor Foo\n\njulia> Functors.children(Foo(1,2))\n(x = 1, y = 2)\n\njulia> _, re = Functors.functor(Foo(1,2));\n\njulia> re((10, 20))\nFoo(10, 20)\n\njulia> struct TwoThirds a; b; c; end\n\njulia> @functor TwoThirds (a, c)\n\njulia> ch2, re3 = Functors.functor(TwoThirds(10,20,30));\n\njulia> ch2\n(a = 10, c = 30)\n\njulia> re3((\"ten\", \"thirty\"))\nTwoThirds(\"ten\", 20, \"thirty\")\n\njulia> fmap(x -> 10x, TwoThirds(Foo(1,2), Foo(3,4), 56))\nTwoThirds(Foo(10, 20), Foo(3, 4), 560)\n\n\n\n\n\n","category":"macro"},{"location":"api/","page":"API","title":"API","text":"Functors.functor\nFunctors.children\nFunctors.isleaf","category":"page"},{"location":"api/#Functors.functor","page":"API","title":"Functors.functor","text":"Functors.functor(x) = functor(typeof(x), x)\n\nReturns a tuple containing, first, a NamedTuple of the children of x (typically its fields), and second, a reconstruction funciton. This controls the behaviour of fmap.\n\nMethods should be added to functor(::Type{T}, x) for custom types, usually using the macro @functor.\n\n\n\n\n\n","category":"function"},{"location":"api/#Functors.children","page":"API","title":"Functors.children","text":"Functors.children(x)\n\nReturn the children of x as defined by functor. Equivalent to functor(x)[1].\n\n\n\n\n\n","category":"function"},{"location":"api/#Functors.isleaf","page":"API","title":"Functors.isleaf","text":"Functors.isleaf(x)\n\nReturn true if x has no children according to functor.\n\nExamples\n\njulia> Functors.isleaf(1)\ntrue\n\njulia> Functors.isleaf([2, 3, 4])\ntrue\n\njulia> Functors.isleaf([\"five\", [6, 7]])\nfalse\n\njulia> Functors.isleaf([])\ntrue\n\njulia> Functors.isleaf((8, 9))\nfalse\n\njulia> Functors.isleaf(())\ntrue\n\n\n\n\n\n","category":"function"},{"location":"api/","page":"API","title":"API","text":"Functors.AbstractWalk\nFunctors.DefaultWalk\nFunctors.StructuralWalk\nFunctors.ExcludeWalk\nFunctors.CachedWalk\nFunctors.CollectWalk\nFunctors.AnonymousWalk","category":"page"},{"location":"api/#Functors.AbstractWalk","page":"API","title":"Functors.AbstractWalk","text":"AbstractWalk\n\nAny walk for use with fmap should inherit from this type. A walk subtyping AbstractWalk must satisfy the walk function interface:\n\nstruct MyWalk <: AbstractWalk end\n\nfunction (::MyWalk)(recurse, x, ys...)\n  # implement this\nend\n\nThe walk function is called on a node x in a Functors tree. It may also be passed associated nodes ys... in other Functors trees. The walk function recurses further into (x, ys...) by calling recurse on the child nodes. The choice of which nodes to recurse and in what order is custom to the walk.\n\n\n\n\n\n","category":"type"},{"location":"api/#Functors.DefaultWalk","page":"API","title":"Functors.DefaultWalk","text":"DefaultWalk()\n\nThe default walk behavior for Functors.jl. Walks all the Functors.children of trees (x, ys...) based on the structure of x. The resulting mapped child nodes are restructured into the type of x.\n\nSee fmap for more information.\n\n\n\n\n\n","category":"type"},{"location":"api/#Functors.StructuralWalk","page":"API","title":"Functors.StructuralWalk","text":"StructuralWalk()\n\nA structural variant of Functors.DefaultWalk. The recursion behavior is identical, but the mapped children are not restructured.\n\nSee fmapstructure for more information.\n\n\n\n\n\n","category":"type"},{"location":"api/#Functors.ExcludeWalk","page":"API","title":"Functors.ExcludeWalk","text":"ExcludeWalk(walk, fn, exclude)\n\nA walk that recurses nodes (x, ys...) according to walk, except when exclude(x) is true. Then, fn(x, ys...) is applied instead of recursing further.\n\nTypically wraps an existing walk for use with fmap.\n\n\n\n\n\n","category":"type"},{"location":"api/#Functors.CachedWalk","page":"API","title":"Functors.CachedWalk","text":"CachedWalk(walk[; prune])\n\nA walk that recurses nodes (x, ys...) according to walk and storing the output of the recursion in a cache indexed by x (based on object ID). Whenever the cache already contains x, either:\n\nprune is specified, then it is returned, or\nprune is unspecified, and the previously cached recursion of (x, ys...) returned.\n\nTypically wraps an existing walk for use with fmap.\n\n\n\n\n\n","category":"type"},{"location":"api/#Functors.CollectWalk","page":"API","title":"Functors.CollectWalk","text":"CollectWalk()\n\nA walk that recurses into a node x via Functors.children, storing the recursion history in a cache. The resulting ordered recursion history is returned.\n\nSee fcollect for more information.\n\n\n\n\n\n","category":"type"},{"location":"api/#Functors.AnonymousWalk","page":"API","title":"Functors.AnonymousWalk","text":"AnonymousWalk(walk_fn)\n\nWrap a walk_fn so that AnonymousWalk(walk_fn) isa AbstractWalk. This type only exists for backwards compatability and should be directly used. Attempting to wrap an existing AbstractWalk is a no-op (i.e. it is not wrapped).\n\n\n\n\n\n","category":"type"},{"location":"api/","page":"API","title":"API","text":"Functors.fmapstructure\nFunctors.fcollect","category":"page"},{"location":"api/#Functors.fmapstructure","page":"API","title":"Functors.fmapstructure","text":"fmapstructure(f, x; exclude = isleaf)\n\nLike fmap, but doesn't preserve the type of custom structs. Instead, it returns a NamedTuple (or a Tuple, or an array), or a nested set of these.\n\nUseful for when the output must not contain custom structs.\n\nExamples\n\njulia> struct Foo; x; y; end\n\njulia> @functor Foo\n\njulia> m = Foo([1,2,3], [4, (5, 6), Foo(7, 8)]);\n\njulia> fmapstructure(x -> 2x, m)\n(x = [2, 4, 6], y = Any[8, (10, 12), (x = 14, y = 16)])\n\njulia> fmapstructure(println, m)\n[1, 2, 3]\n4\n5\n6\n7\n8\n(x = nothing, y = Any[nothing, (nothing, nothing), (x = nothing, y = nothing)])\n\n\n\n\n\n","category":"function"},{"location":"api/#Functors.fcollect","page":"API","title":"Functors.fcollect","text":"fcollect(x; exclude = v -> false)\n\nTraverse x by recursing each child of x as defined by functor and collecting the results into a flat array, ordered by a breadth-first traversal of x, respecting the iteration order of children calls.\n\nDoesn't recurse inside branches rooted at nodes v for which exclude(v) == true. In such cases, the root v is also excluded from the result. By default, exclude always yields false.\n\nSee also children.\n\nExamples\n\njulia> struct Foo; x; y; end\n\njulia> @functor Foo\n\njulia> struct Bar; x; end\n\njulia> @functor Bar\n\njulia> struct NoChildren; x; y; end\n\njulia> m = Foo(Bar([1,2,3]), NoChildren(:a, :b))\nFoo(Bar([1, 2, 3]), NoChildren(:a, :b))\n\njulia> fcollect(m)\n4-element Vector{Any}:\n Foo(Bar([1, 2, 3]), NoChildren(:a, :b))\n Bar([1, 2, 3])\n [1, 2, 3]\n NoChildren(:a, :b)\n\njulia> fcollect(m, exclude = v -> v isa Bar)\n2-element Vector{Any}:\n Foo(Bar([1, 2, 3]), NoChildren(:a, :b))\n NoChildren(:a, :b)\n\njulia> fcollect(m, exclude = v -> Functors.isleaf(v))\n2-element Vector{Any}:\n Foo(Bar([1, 2, 3]), NoChildren(:a, :b))\n Bar([1, 2, 3])\n\n\n\n\n\n","category":"function"},{"location":"#Functors.jl","page":"Home","title":"Functors.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Functors.jl provides a set of tools to represent functors. Functors are a powerful means to apply functions to generic objects without changing their structure.","category":"page"},{"location":"","page":"Home","title":"Home","text":"The most straightforward use is to traverse a complicated nested structure as a tree, and apply a function f to every field it encounters along the way.","category":"page"},{"location":"","page":"Home","title":"Home","text":"For large models it can be cumbersome or inefficient to work with parameters as one big, flat vector, and structs help manage complexity; but it may be desirable to easily operate over all parameters at once, e.g. for changing precision or applying an optimiser update step.","category":"page"},{"location":"#Basic-Usage-and-Implementation","page":"Home","title":"Basic Usage and Implementation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"When one marks a structure as @functor it means that Functors.jl is allowed to look into the fields of the instances of the struct and modify them. This is achieved through Functors.fmap.","category":"page"},{"location":"","page":"Home","title":"Home","text":"The workhorse of fmap is actually a lower level function, functor:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using Functors\n\njulia> struct Foo\n         x\n         y\n       end\n\njulia> @functor Foo\n\njulia> foo = Foo(1, [1, 2, 3]) # notice all the elements are integers\n\njulia> xs, re = Functors.functor(foo)\n((x = 1, y = [1, 2, 3]), var\"#21#22\"())\n\njulia> re(map(float, xs)) # element types have been switched out for floating point numbers\nFoo(1.0, [1.0, 2.0, 3.0])","category":"page"},{"location":"","page":"Home","title":"Home","text":"functor returns the parts of the object that can be inspected, as well as a reconstruction function (shown as re) that takes those values and restructures them back into an object of the original type.","category":"page"},{"location":"","page":"Home","title":"Home","text":"To include only certain fields of a struct, one can pass a tuple of field names to @functor:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> struct Baz\n         x\n         y\n       end\n\njulia> @functor Baz (x,)\n\njulia> model = Baz(1, 2)\nBaz(1, 2)\n\njulia> fmap(float, model)\nBaz(1.0, 2)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Any field not in the list will be passed through as-is during reconstruction. This is done by invoking the default constructor, so structs that define custom inner constructors are expected to provide one that acts like the default.","category":"page"},{"location":"#Appropriate-Use","page":"Home","title":"Appropriate Use","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"warning: Not everything should be a functor!\nDue to its generic nature it is very attractive to mark several structures as @functor when it may not be quite safe to do so.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Typically, since any function f is applied to the leaves of the tree, but it is possible for some functions to require dispatching on the specific type of the fields causing some methods to be missed entirely.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Examples of this include element types of arrays which typically have their own mathematical operations defined. Adding a @functor to such a type would end up missing methods such as +(::MyElementType, ::MyElementType). Think RGB from Colors.jl.","category":"page"}]
}
