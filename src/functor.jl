functor(x) = (), _ -> x

functor(x::Tuple) = x, y -> y
functor(x::NamedTuple) = x, y -> y

functor(x::AbstractArray) = x, y -> y
functor(x::AbstractArray{<:Number}) = (), _ -> x

function makefunctor(m::Module, T, fs = fieldnames(T))
  @eval m begin
    Flux.functor(x::$T) = ($([:($f=x.$f) for f in fs]...),), y -> $T(y...)
  end
end

function functorm(T, fs = nothing)
  fs == nothing || isexpr(fs, :tuple) || error("@functor T (a, b)")
  fs = fs == nothing ? [] : [:($(map(QuoteNode, fs.args)...),)]
  :(makefunctor(@__MODULE__, $(esc(T)), $(fs...)))
end

macro functor(args...)
  functorm(args...)
end

isleaf(x) = functor(x)[1] === ()

function fmap1(f, x)
  func, re = functor(x)
  re(map(f, func))
end

function fmap(f, x; cache = IdDict())
  haskey(cache, x) && return cache[x]
  cache[x] = isleaf(x) ? f(x) : fmap1(x -> fmap(f, x, cache = cache), x)
end
