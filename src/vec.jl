
"""
    fvec(obj; [walk, exclude, ...])

This creates one vector from all the arrays of numbers in `obj`,
i.e. all nodes for which [`isnumeric`](@ref)`(x) == true`.
Differentiable.

# Examples
```jldoctest
julia> fvec((a=[1,2], b=3, c=[4,5], d=nothing))
4-element Vector{Int64}:
 1
 2
 4
 5

julia> struct Foo; x; y; end; @functor Foo

julia> fvec(Foo(1,2))
Float32[]

julia> twice = [1,2];

julia> m = Foo(twice, Foo(([3,4], 5), transpose(twice)))
Foo([1, 2], Foo(([3, 4], 5), [1 2]))

julia> fvec(m)
4-element Vector{Int64}:
 1
 2
 3
 4
```

# Keywords:
* `walk=_structure_walk`, the result of `fmap` is discarded.
* `exclude=isnumeric`.
* All others passed to `fmap`, e.g. `pointers=false`.
"""
function fvec(model; walk=_structure_walk, exclude=isnumeric, kw...)
    arrays = AbstractVector[]
    fmap(model; walk, exclude, kw...) do x
        push!(arrays, vec(x))
    end
    flat = isempty(arrays) ? Float32[] : reduce(vcat, arrays)
end

# TODO: Should you be able to control the type of the output vector?
#       What happens to complex numbers, or a mix of real & complex?
#       Should a different `exclude` let you include numbers?

"""
    Functors.isnumeric(x)

Returns `true` for leaf nodes which are arrays of numbers,
except arrays of booleans.

# Examples
```jldoctest
julia> Functors.isnumeric(range(0, 2pi, length=9))
true

julia> Functors.isnumeric(transpose([1,2,3]))  # not a leaf node
false

julia> Functors.isnumeric([1,2,3] .> 1)
false
```
"""
isnumeric(x::AbstractArray{<:Number}) = isleaf(x)
isnumeric(x::AbstractArray{<:Bool}) = false
isnumeric(x) = false

"""
    Functors.flatlength(obj)

This computes `length(fvec(obj))` without creating the vector.
"""
function flatlength(model; exclude=isnumeric, walk=_structure_walk, kw...)
    len = Ref(0)
    fmap(model; walk, exclude, kw...) do x
        len[] += length(x)
    end
    len[]
end

"""
    fcopy(obj, flat; [walk, exclude, len, ...])
    fview(obj, flat; kw...)

Uses `fmap` to reconstruct an object like the one given,
replacing arrays with the data from a given vector, with
the layout as `fvec(obj)`. 

With `fview`, every array in the result is a view of the given vector.

Differentiable.

# Examples
```jldoctest
julia> nt = (a=[1,2], b=3, c=[4,5], d=sin);

julia> fcopy(nt, [10, 20, 30, 40])
(a = [10, 20], b = 3, c = [30, 40], d = sin)

julia> struct Foo; x; y; end; @functor Foo

julia> twice = [1,2];

julia> m = Foo(twice, Foo([3,4], transpose(twice)))
Foo([1, 2], Foo([3, 4], [1 2]))

julia> m10 = fview(m, [10, 20, 30, 40])
Foo([10, 20], Foo([30, 40], [10 20]))

julia> m10.x === m10.y.y.parent
true
```

# Keywords:
* `walk = _default_walk` to reconstruct fully.
* `exclude = isnumeric`, to match `fvec`.
* `len = flatlength(model; exclude)` is used only to give an error on wrong length `flat`.
* All others passed to `fmap`, e.g. `prune = nothing` for gradients.
"""
fcopy(model, flat::AbstractVector; kw...) = _fcopy(getindex, model, flat; kw...)

function _fcopy(getter::F, model, flat::AbstractVector{T}; 
        walk=_default_walk, exclude=isnumeric, len=flatlength(model; exclude), kw...) where {F<:Function, T}
    length(flat) == len || throw(DimensionMismatch(
        "model with flatlength(m) == $(len) cannot be reconstructed from parameter vector length(flat) == $(length(flat))"))
    offset = Ref(0)
    fmap(model; walk, exclude, kw...) do x
        y = getter(flat, offset .+ (1:length(x)))
        offset[] += length(x)
        reshape(y, axes(x))
    end
end

@doc @doc(fcopy)
fview(model, flat::AbstractVector; kw...) = _fcopy(view, model, flat; kw...)

# TODO: Should this restore types, e.g. if model has Float32 and Float64 parts?
#       Or complex & real.

# function getarray(::typeof(getindex), flat::AbstractVector, offset::Int, x::AbstractArray)
#     y = similar(x, float(eltype(x)), axes(x))
#     copyto!(y, firstindex(y), flat, offset+1, length(x))
#     y
# end
# function getarray(::typeof(view), flat::AbstractVector, offset::Int, x::AbstractArray)
#     reshape(view(flat, offset .+ (1:length(x))), axes(x))
# end



"""
    Functors.flatgrad!(flat, obj, grad)

This walks both `obj` and `grad` together, to write arrays from the gradient
into the `flat` vector at the same location that `fvec(obj)` would write the
corresponding array.

Gradients for arrays appearing more than once in `obj` are added.
If there is no gradient for an array, then `flat` is filled with `0` there.
There is no requirement that `grad` define `functor`.

Exists because the gradient rule for `fcopy` needs it.

# Examples
```jldoctest
julia> nt = (a=[1,2], b=3, c=[4,5], d=sin);

julia> Functors.flatgrad!(rand(4), nt, (a=nothing, c=[10, 20]))
4-element Vector{Float64}:
  0.0
  0.0
 10.0
 20.0

julia> fcopy(nt, ans)
(a = [0.0, 0.0], b = 3, c = [10.0, 20.0], d = sin)

julia> struct Foo; x; y; end; @functor Foo

julia> twice = [1,2];

julia> m = Foo(twice, Foo([3,4], transpose(twice)))
Foo([1, 2], Foo([3, 4], [1 2]))

julia> Functors.flatlength(m)
4

julia> Functors.flatgrad!(rand(4), m, (x=[10,20], y=(x=[30,40], y=[100,200]')))
4-element Vector{Float64}:
 110.0
 220.0
  30.0
  40.0
```

# Keywords:
* `exclude = isnumeric`, to match `fvec` / `fcopy`.
* `children = children`, specifies which elements to walk.
"""
function flatgrad!(flat::AbstractVector, x, dx; exclude=isnumeric, children=children, offset::Ref=Ref(0), indices=IdDict())
    if !isbits(x) && haskey(indices, x)
        # x is a duplicate of an earlier array
        if dx isa AbstractArray
            # ... and we have a new gradient to accumulate.
            size(x) == size(dx) || throw(DimensionMismatch(
                "array with size(x) == $(size(x)) cannot have a gradient with size(dx) == $(size(dx))"))
            ix = indices[x]::Int
            view(flat, ix .+ (1:length(x))) .+= vec(dx)
        end
    elseif exclude(x)
        # x is a newly seen array
        if !isbits(x)
            indices[x] = offset[]
        end
        if dx isa AbstractArray
            size(x) == size(dx) || throw(DimensionMismatch(
                "array with size(x) == $(size(x)) cannot have a gradient with size(dx) == $(size(dx))"))
            copyto!(flat, offset[]+1, dx)
        else
            # There is no matching gradient, so write zeros
            ix = offset[]
            view(flat, ix .+ (1:length(x))) .= 0
        end
        offset[] += length(x)
    elseif !isleaf(x)
        if dx isa AbstractArray && lazywrap(x) !== nothing
            # e.g. Transpose is non-leaf, but its gradient might be a Matrix
            y, un = lazywrap(x)
            flatgrad!(flat, y, un(dx); offset, indices)
        else
            # x is a container, so recurse inwards.
            # We know x is functor-like, but dx may not be, e.g. Tangent
            for (key, val) in pairs(children(x))
                dxval = key in propertynames(dx) ? getproperty(dx, key) : nothing
                flatgrad!(flat, val, dxval; offset, indices)
            end
        end
    end
    flat
end

using ChainRulesCore

"""
Gradient rule for `fcopy`:

```jldoctest
julia> nt = (a=[1,2], b=3, c=[4,5], d=sin);

julia> using Zygote

julia> gradient(v -> sum(abs2, fcopy(nt, v).c), [1, 2, 3, 4])  # rrule for fcopy
([0.0, 0.0, 6.0, 8.0],)

julia> gradient(m -> sum(abs2, m.x .+ 10 .* m.y.y), m)  # no Functors involvement
((x = [64.0, 68.0], y = (x = nothing, y = [460.0 860.0])),)

julia> gradient([1, 2, 3, 4]) do v  # accumulates contributions to `twice`
          mre = fcopy(m, v)
          sum(abs2, mre.x .+ 10 .* mre.y.y)
       end
([524.0, 928.0, 0.0, 0.0],)
```
"""
function ChainRulesCore.rrule(::typeof(_fcopy), get::F, model, flat::AbstractVector;
        exclude=isnumeric, len=flatlength(model; exclude), kw...) where {F}
    function fcopy_pullback(dm)
        out = similar(flat, float(eltype(flat)))
        flatgrad!(out, model, dm; exclude)
        return (NoTangent(), NoTangent(), NoTangent(), out)
    end
    # Note that we can't pass walk keyword through here, as `flatgrad!` doesn't use it. Could it?
    _fcopy(get, model, flat; exclude, len), fcopy_pullback
end

"""
Gradient rule for `fvec`:

```jldoctest
julia> struct Foo; x; y; end; @functor Foo

julia> twice = [1,2];

julia> m = Foo(twice, Foo(([3,4], 5), transpose(twice)));

julia> using Zygote

julia> gradient(v -> sum(abs2, v), fvec(m))  # no Functors involvement
([2.0, 4.0, 6.0, 8.0],)

julia> gradient(m -> sum(abs2, fvec(m)), m)  # rrule for fvec
((x = [2.0, 4.0], y = (x = ([6.0, 8.0], nothing), y = nothing)),)

julia> fvec(ans) |> tuple
([2.0, 4.0, 6.0, 8.0],)
```

It's important that the derivative for `fvec` prunes the gradient tree,
so that the gradient of a tied array (like `twice`) is not later counted twice.
"""
function ChainRulesCore.rrule(::typeof(fvec), model; walk=_structure_walk)
    flat = fvec(model)
    len = length(flat)
    function _Tangent_walk(f, x)
        b = walk(f, x)
        b isa Union{Tuple{}, NamedTuple{()}} && return NoTangent()  # not very happy here
        Tangent{typeof(x), typeof(b)}(b)
    end
    function fvec_pullback(delta)
        dm = fcopy(model, float(delta); walk=_Tangent_walk, prune=ZeroTangent(), len=len)
        return (NoTangent(), dm)
    end
    flat, fvec_pullback
end

# Something like `Flux.destructure` is now a trivial combination of `fvec` and `fcopy`.
# (Both `re` functions need to keep a whole copy of the model, not just the sizes & types.)
# With the combined function, you cannot accidentally pass different keywords to the two.

# allerretour(model) = fvec(model), Base.Fix1(fcopy, model)

# function Base.show(io::IO, re::Base.Fix1{typeof(fcopy)})
#     print(io, "Fix1(fcopy, ", typeof(re.x).name.name, "(...))")
# end

#=

julia> destructure(model) = fvec(model), delta -> fcopy(model, delta);

julia> twice = [1,2];

julia> m = Foo(twice, Foo([3,4], transpose(twice)));

julia> g1 = gradient(m) do m
           m.x[1] + sum(abs2, m.x .+ 10 .* m.y.y)
       end
((x = [65.0, 68.0], y = (x = nothing, y = [460.0 860.0])),)

julia> g1[1].y.y isa Transpose  # due to ProjectTo, thus it has field .parent
true

julia> g2 = gradient(m) do m
           v, re = destructure(m)
           v[1] + sum(abs2, re(v).x .+ 10 .* re(v).y.y)
       end
((x = [525.0, 928.0], y = (x = [0.0, 0.0], y = nothing)),)

julia> g1[1].y.y.parent == g1[1].x  # these are not tied, need to accumulate
false

julia> Functors.flatgrad!(rand(4), m, g1[1])
4-element Vector{Float64}:
 525.0
 928.0
   0.0
   0.0

julia> (g2[1].y.y, g2[1].x)  # now also not tied. This is where `prune` keyword is essential...
(nothing, [525.0, 928.0])

julia> Functors.flatgrad!(rand(4), m, g2[1])  # ... because this function has no way to know not to add them.
4-element Vector{Float64}:
 525.0
 928.0
   0.0
   0.0

# OK maybe that now works. The version of `fcopy` used in the gradient of `fvec` deliberately
# omits some branches, because leaving the gradients just === isn't a clear sign: That will
# happen accidentally, e.g. the `rrule` can return `Fill` etc. 

julia> g3 = gradient(m -> sum(abs2, m.x + transpose(m.y.y)), m)
((x = [4, 8], y = (x = nothing, y = [4 8])),)

julia> g3[1].x === g3[1].y.y.parent  # accidentally === due to rrule(+)
true

julia> g4 = gradient(m -> sum(m.x) + sum(transpose(m.y.y)), m)
((x = Fill(1, 2), y = (x = nothing, y = [1 1])),)

julia> g4[1].x === g4[1].y.y.parent  # immutable
true

=#
