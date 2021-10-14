"""
    Functor{T, FS}

Type-level representation of a [base functor](https://hackage.haskell.org/package/recursion-schemes-5.2.2.1/docs/Data-Functor-Foldable-TH.html).
A `Functor` wraps a struct of type `T` using a backing of type `FS`.
`Functors` also implement `getindex` and `getproperty` to act as rough proxies for the original type's structure.

Note that not all types need to be wrapped in `Functor`.
Notable exceptions include primitives, tuples and arrays.
For an explanation of why we need base functors, see [here](https://blog.sumtypeofway.com/posts/recursion-schemes-part-4-point-5.html).
To implement a `Functor` wrapper for your own class, see [`@functor`](@ref).
"""
struct Functor{T,FS}
    inner::FS
end

Functor{T}(inner) where T = Functor{T,typeof(inner)}(inner)

"""
    functor(::Type{T}, args...)
    functor(::Type{T}; kwargs...)

Convenience function for manually instantiating [`Functor`](@ref)s of type `T`.
"""
functor(::Type{T}, args...) where T = Functor{T}(NamedTuple{fieldnames(T)}(args))
functor(::Type{T}; kwargs...) where T = Functor{T}(NamedTuple{fieldnames(T)}(values(kwargs)))

"""
    backing(func)

Returns the backing storage of a [`Functor`](@ref).
For unwrapped types, this is a no-op.
For wrapped struct types, this returns every field in the original struct.
If you only want the fields that are mapped over, see [`Functors.children`](@ref).
"""
backing(func) = func
backing(func::Functor) = getfield(func, :inner)

# TODO better name
"""
    children(func)

Returns the child nodes of a [`Functor`](@ref).
For types that have not opted into the `Functor` interface, this returns `nothing`.
For many special-cased base types, this is a no-op.
For wrapped struct types, this returns the fields that can mapped over with [`Functors.fmap`](@ref).
"""
children(_) = nothing
children(x::Functor) = backing(x)

"""
    isleaf(func)

Determines if a given value is a leaf node, i.e. it is not a functor or has no children.
By default, any type that has not implemented the functor interface is considered a leaf node.
"""
isleaf(x) = children(x) === nothing

Base.getproperty(func::Functor, prop::Symbol) = getproperty(backing(func), prop)
Base.getindex(func::Functor, prop) = getindex(backing(func), prop)

"""
    fmap(f, x)
    fmap(f, xs...)

A [structure and type preserving](https://hackage.haskell.org/package/base-4.15.0.0/docs/Prelude.html#v:fmap) `map` that works for all functors.
Similar to `map` on a `Tuple` or `NamedTuple`, except it works for any type that implements the functor interface.

When multiple inputs `xs...` are provided, `fmap` will return a Functor with the structure of the first input.

# Examples
```jldoctest
julia> struct Foo; x; y; z; end
julia> @functor Foo (x, z)
julia> foo = Foo(1, 3, 5);
julia> func = fmap(x -> 2x, project(foo))
Functor{Foo}((x=2, y=3, z=10))
julia> embed(func)
Foo(2, 3, 10)
```
"""
fmap(_, x) = x
fmap(_, xs...) = xs
fmap(f, func::Functor{T}) where T = Functor{T}(map(f, backing(func)))
fmap(f, func::Functor, funcs...) where T = Functor{T}(map(f, backing(func), map(backing, funcs)...))

"""
    project(x)

Transforms a plain Julia value into its functor representation.
For types that have not opted into the `Functor` interface and special-cased base types, this is a no-op.
For wrapped struct types, this returns a [`Functor`](@ref).
"""
project(x) = x

"""
    embed(func)

Transforms a functor back into its plain Julia representation.
For [`Functor`](@ref)s, this returns the original wrapped struct type.
For types that have not opted into the `Functor` interface and special-cased base types, this is a no-op.
"""
embed(func) = func
# TODO use ConstructionBase?
embed(func::Functor{T}) where T = T(backing(func)...)

function makefunctor(m::Module, T, fs=fieldnames(T))
    escfields = [:(x.$field) for field in fieldnames(T)]
    escfs = [:($field = func.$field) for field in fs]
    escfmap = map(fieldnames(T)) do field
        field in fs ? :(f(func.$field)) : :(func.$field)
    end
    escvfmap = map(fieldnames(T)) do field
        field ∉ fs && :(func.$field)
        :(f(func.$field, getproperty.(funcs, $(Meta.quot(field)))...))
    end
  
    @eval m begin
        $Functors.project(x::$T) = $Functors.functor($T, $(escfields...))
        $Functors.children(func::$Functors.Functor{$T}) = ($(escfs...),)
        # Ref. https://gitlab.haskell.org/ghc/ghc/-/wikis/commentary/compiler/derive-functor
        $Functors.fmap(f, func::$Functors.Functor{$T}) = $Functors.functor($T, $(escfmap...))
        function $Functors.fmap(f, func::$Functors.Functor{$T}, funcs...)
            # @show typeof(funcs)
            # @show ($Functors.functor($T, $(escvfmap...)), funcs...)
            $Functors.functor($T, $(escvfmap...))
        end
    end
end

function functorm(T, fs=nothing)
    fs === nothing || Meta.isexpr(fs, :tuple) || error("@functor T (a, b)")
    fs = fs === nothing ? [] : [:($(map(QuoteNode, fs.args)...),)]
    :(makefunctor(@__MODULE__, $(esc(T)), $(fs...)))
end

"""
    @functor T
    @functor T (field1, field2, ...)

Fancy macro that automatically implements the functor interface for a given type `T`.
This includes [`Functors.project`](@ref), [`Functors.children`](@ref) and [`Functors.fmap`](@ref).

By default, `@functor T` will include all fields of the original type as children in the [`Functor`](@ref) representation.
To include only certain fields, pass a tuple of field names to `@functor`.
Passing the empty tuple like `@functor T ()` will exclude all fields from being child nodes.
"""
macro functor(args...)
    functorm(args...)
end

# built-ins
const JLCollection = Union{Tuple,NamedTuple,AbstractArray}
children(xs::T) where T <: JLCollection = xs
project(xs::T) where T <: JLCollection = map(project, xs)
embed(xs::T) where T <: JLCollection = map(embed, xs)
fmap(f, xs::T) where T <: JLCollection = map(f, xs)
fmap(f, xs::T, xss...) where T <: JLCollection = map(f, xs, map(backing, xss)...)

@static if VERSION >= v"1.6"
    @functor Base.ComposedFunction
end
