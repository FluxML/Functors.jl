# recursion schemes
struct Fold{F,C}
    fn::F
    cache::C
end
Fold(f) = Fold(f, IdDict())

function (f::Fold)(x)
    haskey(f.cache, x) && return f.cache[x]
    f.cache[x] = f.fn(fmap(f, project(x)))
end

struct Unfold{F,C}
    fn::F
    cache::C
end
Unfold(f) = Unfold(f, IdDict())

function (f::Unfold)(x)
    haskey(f.cache, x) && return f.cache[x]
    f.cache[x] = embed(fmap(f, f.fn(x)))
end

fold(f, x) = Fold(f)(x)
ana(f, x) = Unfold(f)(x)

# aliases
const cata = fold
const ana = unfold

# convenience functions
rfmap(f, x) = fold(embed ∘ f, x)