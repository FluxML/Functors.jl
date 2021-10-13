# Ordinarily separate instances of mutable types would have distinct objectids
# (or at least fail a === test), but String is an exception to both.
# This function exists purely to handle that edge case.
iscacheable(x) = ismutable(x)
iscacheable(::String) = false

## Generalized folds (Catamorphisms)
struct Fold{F,I,C}
    fn::F
    isleaf::I
    cache::C
end

function _fold_helper(f, x)
    y = project(x)
    f.fn(f.isleaf(y) ? y : fmap(f, y))
end

function _fold_helper(f, xs...)
    ys = map(project, xs)
    # TODO are there times when we _should_ recurse despite a leaf?
    any(f.isleaf, ys) ? f.fn(ys...) : f.fn(fmap((xs′...) -> f(xs′...), ys...))
end

(f::Fold)(x) = !iscacheable(x) ? get!(() -> _fold_helper(f, x), f.cache, x) : _fold_helper(f, x)
function (f::Fold)(xs...) 
    all(iscacheable, xs) || _fold_helper(f, xs...)
    get!(() -> _fold_helper(f, xs...), f.cache, xs)
end

"""
    fold(f, x; isleaf, cache)
    fold(f, x; isleaf, cache, accum, accum_cache)
"""
fold(f, x; isleaf=isleaf, cache=IdDict()) = Fold(f, isleaf, cache)(x)
fold(f, xs...; isleaf=isleaf, cache=IdDict()) = Fold(f, isleaf, cache)(xs...)

"""
Alias for [fold](@ref)
"""
const cata = fold


## Generalized unfolds (Anamorphisms)
struct Unfold{F,C}
    fn::F
    cache::C
end

_unfold_helper(u, x) = embed(fmap(u, u.fn(x)))
_unfold_helper(u, xs...) = map(embed, fmap((ys...) -> u(ys...), u.fn(xs...)))

# (u::Unfold)(x) = ismutable(x) ? get!(() -> _unfold_helper(u, x), u.cache, x) : _unfold_helper(u, x)
(u::Unfold)(x, xs...) = ismutable(x) ? get!(() -> _unfold_helper(u, x, xs...), u.cache, x) : _unfold_helper(u, x, xs...)

unfold(f, x; cache=IdDict()) = Unfold(f, cache)(x)
unfold(f, xs...; cache=IdDict()) = Unfold(f, cache)(xs...)
const ana = unfold


## Convenience functions
rfmap(f, x) = fold(embed ∘ f, x)
rfmap(f, xs...) = embed(fold(xs...) do (ys...)
    embed(length(ys) > 1 ? f(ys...) : only(ys))
end)