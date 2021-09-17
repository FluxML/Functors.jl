struct Functor{T,FS}
    inner::FS
end

Functor{T}(inner) where T = Functor{T,typeof(inner)}(inner)
functor(::Type{T}, args...) where T = Functor{T}(NamedTuple{fieldnames(T)}(args))
functor(::Type{T}; kwargs...) where T = Functor{T}(NamedTuple{fieldnames(T)}(values(kwargs)))

backing(x) = x
backing(func::Functor) = getfield(func, :inner)
# TODO better name
children(_) = nothing
children(x::Functor) = backing(x)
isleaf(x) = children(x) === nothing

Base.getproperty(func::Functor, prop::Symbol) = getproperty(backing(func), prop)
Base.getindex(func::Functor, prop) = getindex(backing(func), prop)

fmap(_, x) = x
fmap(_, xs...) = xs
fmap(f, func::Functor{T}) where T = Functor{T}(map(f, backing(func)))
fmap(f, func::Functor, funcs...) where T = Functor{T}(map(f, backing(func), map(backing, funcs)...))

project(x) = x
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
