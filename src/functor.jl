struct Functor{T,FS}
    inner::FS
end

Functor{T}(inner) where T = Functor{T,typeof(inner)}(inner)
backing(x) = x
backing(func::Functor) = getfield(func, :inner)

Base.getproperty(func::Functor, prop::Symbol) = getproperty(backing(func), prop)
Base.getindex(func::Functor, prop) = getindex(backing(func), prop)

fmap(_, x) = x
fmap(f, func::Functor{T}) where T = Functor{T}(map(f, backing(func)))

project(x) = x
embed(func) = func

function makefunctor(m::Module, T, fs=fieldnames(T))
    escfs = [:($f = x.$f) for f in fs]
    @eval m begin
        $Functors.project(x::$T) = $Functors.Functor{$T}(($(escfs...),))
        # TODO use ConstructionBase?
        $Functors.embed(func::$Functors.Functor{$T}) = $T($Functors.backing(func)...)
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

# recursion schemes
cata(f, x) = f(fmap(y -> cata(f, y), project(x)))
ana(f, x) = embed(fmap(y -> ana(f, y), f(x)))

# aliases
const fold = cata
const unfold = ana

# convenience functions
rfmap(f, x) = cata(embed ∘ f, x)

# built-ins
fmap(f, xs::T) where T <: Union{Tuple,NamedTuple,AbstractArray} = map(f, xs)

@static if VERSION >= v"1.6"
    @functor Base.ComposedFunction
end
