# recursion schemes
struct Fold{F,I,C}
    fn::F
    isleaf::I
    cache::C
end

(f::Fold)(x) = get!(f.cache, x) do
    y = project(x)
    f.fn(f.isleaf(y) ? y : fmap(f, y))
end

(f::Fold)(xs...) = get!(f.cache, xs) do
    ys = map(project, xs)
    ys = f.isleaf(ys[1]) ? ys : fmap((xs′...) -> f(xs′...), ys...)
    ys isa Tuple ? f.fn(ys...) : f.fn(ys)
end

struct Unfold{F,C}
    fn::F
    cache::C
end

function (u::Unfold)(x)
    haskey(u.cache, x) && return u.cache[x]
    u.cache[x] = embed(fmap(u, u.fn(x)))
end
    
function (u::Unfold)(xs...)
    haskey(u.cache, xs) && return u.cache[xs]
    u.cache[xs] = map(embed, fmap((ys...) -> u(ys...), u.fn(xs...)))
end

fold(f, x; isleaf=isleaf, cache=IdDict()) = Fold(f, isleaf, cache)(x)
fold(f, xs...; isleaf=isleaf, cache=IdDict()) = Fold(f, isleaf, cache)(xs...)
unfold(f, x) = Unfold(f)(x)
unfold(f, xs...) = Unfold(f)(xs...)

# aliases
const cata = fold
const ana = unfold

# convenience functions
rfmap(f, x) = fold(embed ∘ f, x)
rfmap(f, xs...) = embed(fold(xs...) do (ys...)
    embed(length(ys) > 1 ? f(ys...) : only(ys))
end)