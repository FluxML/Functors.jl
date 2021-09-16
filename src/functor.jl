struct Functor{T,FS}
    inner::FS
end

Functor{T}(inner) where T = Functor{T,typeof(inner)}(inner)
functor(::Type{T}, args...) where T = Functor{T}(NamedTuple{fieldnames(T)}(args))
functor(::Type{T}; kwargs...) where T = Functor{T}(NamedTuple{fieldnames(T)}(values(kwargs)))

backing(x) = x
backing(func::Functor) = getfield(func, :inner)
# TODO better name
children(x) = backing(x)

Base.getproperty(func::Functor, prop::Symbol) = getproperty(backing(func), prop)
Base.getindex(func::Functor, prop) = getindex(backing(func), prop)

fmap(_, x) = x
fmap(f, func::Functor{T}) where T = Functor{T}(map(f, backing(func)))

project(x) = x
embed(func) = func
# TODO use ConstructionBase?
embed(func::Functor{T}) where T = T(backing(func)...)

function makefunctor(m::Module, T, fs=fieldnames(T))
    escfields = [:($field = x.$field) for field in fieldnames(T)]
    escfs = [:($field = func.$field) for field in fs]
    escfmap = map(fieldnames(T)) do field
        field in fs ? :($field = f(func.$field)) : :($field = func.$field)
    end
  
    @eval m begin
        $Functors.project(x::$T) = $Functors.Functor{$T}(($(escfields...),))
        $Functors.children(func::$Functors.Functor{$T}) = ($(escfs...),)
        # Ref. https://gitlab.haskell.org/ghc/ghc/-/wikis/commentary/compiler/derive-functor
        $Functors.fmap(f, func::$Functors.Functor{$T}) = $Functors.Functor{$T}(($(escfmap...),))
    end
end

function functorm(T, fs=nothing)
fs === nothing || Meta.isexpr(fs, :tuple) || error("@functor T (a, b)")
fs = fs === nothing ? [] : [:($(map(QuoteNode, fs.args)...),)]
    :(makefunctor(@__MODULE__, $(esc(T)), $(fs...)))
end

macro functor(args...)
    functorm(args...)
end

# built-ins
fmap(f, xs::T) where T <: Union{Tuple,NamedTuple,AbstractArray} = map(f, xs)

@static if VERSION >= v"1.6"
    @functor Base.ComposedFunction
end
