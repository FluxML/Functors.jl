
"""
    fvec(obj)

This combines all the arrays of numbers in `obj` into one vector,
except for booleans. Differentiable.

# Examples
```jldoctest
julia> fvec((a=[1,2], b=3, c=[4,5], d=nothing))
4-element Vector{Int64}:
 1
 2
 4
 5

julia> struct Foo; x; y; end

julia> @functor Foo

julia> twice = [1,2];

julia> m = Foo(twice, Foo([3,4], transpose(twice)))
Foo([1, 2], Foo([3, 4], [1 2]))

julia> fvec(m)
4-element Vector{Int64}:
 1
 2
 3
 4

julia> using Zygote

julia> gradient(v -> sum(abs2, v), fvec(m))  # no Functors involvement
([2.0, 4.0, 6.0, 8.0],)

julia> gradient(m -> sum(abs2, fvec(m)), m)  # rrule for fvec
((x = [2.0, 4.0], y = (x = [6.0, 8.0], y = (parent = [2.0, 4.0],))),)

julia> fvec(ans) |> tuple
([2.0, 4.0, 6.0, 8.0],)
```
"""
function fvec(model; walk=_structure_walk, kw...)
    arrays = AbstractVector[]
    inner(x::AbstractArray) = push!(arrays, vec(x))
    inner(x::AbstractArray{<:Bool}) = nothing
    inner(x) = nothing
    fmap(inner, model; walk=walk, kw...)
    flat = reduce(vcat, arrays)
end

"""
    Functors.flength(obj)

This computes `length(fvec(obj))` without creating the vector.
"""
function flength(model; walk=_structure_walk, kw...)
    len = 0
    inner(x::AbstractArray) = len += length(x)
    inner(x::AbstractArray{<:Bool}) = nothing
    inner(x) = nothing
    fmap(inner, model; walk=walk, kw...)
    len
end

"""
    fcopy(obj, flat)

Uses `fmap` to reconstruct an object like the one given,
replacing arrays with the data from a vector, such as `fvec(obj)`.
Differentiable.

```jldoctest
julia> nt = (a=[1,2], b=3, c=[4,5], d=sin);

julia> fcopy(nt, [10, 20, 30, 40])
(a = [10, 20], b = 3, c = [30, 40], d = sin)

julia> using Zygote

julia> gradient(v -> sum(abs2, fcopy(nt, v).c), [1, 2, 3, 4])  # rrule for fcopy
([0.0, 0.0, 6.0, 8.0],)

julia> struct Foo; x; y; end

julia> @functor Foo

julia> twice = [1,2];

julia> m = Foo(twice, Foo([3,4], transpose(twice)))
Foo([1, 2], Foo([3, 4], [1 2]))

julia> Functors.fvec(m)
4-element Vector{Int64}:
 1
 2
 3
 4

julia> gradient(m -> sum(abs2, m.x .+ 10 .* m.y.y), m)  # no Functors involvement
((x = [64.0, 68.0], y = (x = nothing, y = [460.0 860.0])),)

julia> gradient([1, 2, 3, 4]) do v  # accumulates contributions to `twice`
          mre = fcopy(m, v)
          sum(abs2, mre.x .+ 10 .* mre.y.y)
       end
([524.0, 928.0, 0.0, 0.0],)
```
"""
function fcopy(model, flat::AbstractVector{T}; walk=Functors._default_walk) where {T}
    flength(model; walk=walk) == length(flat) || throw(DimensionMismatch("wrong length!"))
    i = 0
    function inner(x::AbstractArray)
        y = reshape(flat[i .+ (1:length(x))], axes(x))
        # @info "inner" x i y
        i += length(x)
        y
    end
    inner(x::AbstractArray{<:Bool}) = x
    inner(x) = x
    fmap(inner, model; walk=walk)
end

"""
    Functors.faccumulate!(flat, obj, grad)

This walks both `obj` and `grad` together, to write arrays from the gradient
into the `flat` vector at the same location that `fvec(obj)` would write the
corresponding array.

Gradients for arrays appearing more than once in `obj` are accumulated.
If there is no gradient for an array, then `flat` is filled with `0` there.
There is no requirement that `grad` define `functor`.

```jldoctest
julia> nt = (a=[1,2], b=3, c=[4,5], d=sin);

julia> Functors.faccumulate!(rand(4), nt, (a=nothing, c=[10, 20]))
4-element Vector{Float64}:
  0.0
  0.0
 10.0
 20.0

julia> fcopy(nt, ans)
(a = [0.0, 0.0], b = 3, c = [10.0, 20.0], d = sin)

julia> struct Foo; x; y; end

julia> @functor Foo

julia> twice = [1,2];

julia> m = Foo(twice, Foo([3,4], transpose(twice)))

julia> Functors.flength(m)
4

julia> Functors.faccumulate!(rand(4), m, (x=[10,20], y=(x=[30,40], y=[100,200]')))
4-element Vector{Float64}:
 110.0
 220.0
  30.0
  40.0
```
"""
function faccumulate!(flat::AbstractVector, x, dx; ref::Ref=Ref(1), indices=IdDict())
    if !isleaf(x)
        # x is a container, so recurse inwards
        content, _ = functor(x)  # know x is functor-like, but dx may not be, e.g. Tangent
        for (key, val) in pairs(content)
            dxval = key in propertynames(dx) ? getproperty(dx, key) : nothing
            faccumulate!(flat, val, dxval; ref, indices)
        end
    elseif haskey(indices, x)
        # @info "repeat" x dx indices[x]
        # x is a duplicate of an earlier array
        if isnumeric(dx)
            # and we have a new gradient to accumulate.
            size(x) == size(dx) || throw("bad sizes!")
            ix = indices[x]::Int
            view(flat, ix:ix+length(x)-1) .+= vec(dx)
        end
    elseif isnumeric(x)
        # @info "new" x dx ref[]
        # x is a newly seen array
        indices[x] = ref[]
        if isnumeric(dx)
            size(x) == size(dx) || throw("bad sizes!")
            copyto!(flat, ref[], dx, 1, length(x))
        else
            # there is no matching gradient, so write zeros
            view(flat, ref[]:ref[]+length(x)-1) .= 0
        end
        ref[] += length(x)
    end
    flat
end

isnumeric(x::AbstractArray{<:Number}) = true
isnumeric(x::AbstractArray{<:Bool}) = false
isnumeric(x) = false

using ChainRulesCore

# Functors.functor(t::Tangent) = ChainRulesCore.backing(t), identity

_Tangent_walk(f, x) = Tangent{typeof(x)}(; _structure_walk(f, x)...)

function ChainRulesCore.rrule(::typeof(fcopy), model, flat::AbstractVector)
    function fcopy_pullback(dm)
        out = similar(flat, float(eltype(flat)))
        faccumulate!(out, model, dm)
        return (NoTangent(), NoTangent(), out)
    end
    fcopy(model, flat), fcopy_pullback
end

function ChainRulesCore.rrule(::typeof(fvec), model)
    fvec_pullback(delta) = (NoTangent(), fcopy(model, float(delta); walk=_Tangent_walk))
    fvec(model), fvec_pullback
end

#=

# Something like `Flux.destructure` is now a trivial combination of `fvec` and `fcopy`.
# Both `re` functions need to keep a whole copy of the model, not just the sizes & types.

julia> destructure(model) = fvec(model), Base.Fix1(fcopy, model);

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
((x = [525.0, 928.0], y = (x = [0.0, 0.0], y = (parent = [525.0, 928.0],))),)

julia> g1[1].y.y.parent == g1[1].x  # these are not tied, need to accumulate
false

julia> Functors.faccumulate!(rand(4), m, g1[1])
4-element Vector{Float64}:
 525.0
 928.0
   0.0
   0.0

julia> g2[1].y.y.parent === g2[1].x  # but these are, accumulated during round-trip
true

julia> Functors.faccumulate!(rand(4), m, g2[1])  # and this function doesn't check, wrong.
4-element Vector{Float64}:
 1050.0
 1856.0
    0.0
    0.0

# So the walk isn't quite right yet. But checking `===` of the gradient components
# (which would detect `g1[1].y.y.parent` here) will have false positives in general,
# 

julia> g3 = gradient(m -> sum(abs2, m.x + transpose(m.y.y)), m)
((x = [4, 8], y = (x = nothing, y = [4 8])),)

julia> g3[1].x === g3[1].y.y.parent  # accidentally === due to rrule(+)
true

=#
