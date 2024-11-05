struct WalkCache{K, V, W <: AbstractWalk, C <: AbstractDict{K, V}} <: AbstractDict{K, V}
  walk::W
  cache::C
  WalkCache(walk, cache::AbstractDict{K, V} = IdDict()) where {K, V} = new{K, V, typeof(walk), typeof(cache)}(walk, cache)
end
Base.length(cache::WalkCache) = length(cache.cache)
Base.empty!(cache::WalkCache) = empty!(cache.cache)
Base.haskey(cache::WalkCache, x) = haskey(cache.cache, x)
Base.get(cache::WalkCache, x, default) = haskey(cache.cache, x) ? cache[x] : default
Base.iterate(cache::WalkCache, state...) = iterate(cache.cache, state...)
Base.setindex!(cache::WalkCache, value, key) = setindex!(cache.cache, value, key)
Base.getindex(cache::WalkCache, x) = cache.cache[x]

function __cacheget_generator__(world, source, self, cache, x, args #= for `return_type` only =#)
    # :(return cache.cache[x]::(return_type(cache.walk, typeof(args))))
    walk = cache.parameters[3]
    RT = Core.Compiler.return_type(Tuple{walk, args...}, world)
    body = Expr(:call, GlobalRef(Base, :getindex), Expr(:., :cache, QuoteNode(:cache)), :x)
    if RT != Any
        body = Expr(:(::), body, RT)
    end
    expr = Expr(:lambda, [Symbol("#self#"), :cache, :x, :args],
                Expr(Symbol("scope-block"), Expr(:block, Expr(:meta, :inline), Expr(:return, body))))
    ci = ccall(:jl_expand, Any, (Any, Any), expr, @__MODULE__)
    ci.inlineable = true
    if hasfield(Core.CodeInfo, :nargs)
        ci.nargs = 4
        ci.isva = true
    end
    if isdefined(Base, :__has_internal_change) && Base.__has_internal_change(v"1.12-alpha", :codeinfonargs)
        ci.nargs = 4
        ci.isva = true
    end
    return ci
end

@eval function cacheget(cache::WalkCache, x, args...)
    $(Expr(:meta, :generated, __cacheget_generator__))
    $(Expr(:meta, :generated_only))
end

# fallback behavior that only lookup for `x`
@inline cacheget(cache::AbstractDict, x, args...) = cache[x]
