using Functors: erased_children, erased_isleaf, ErasedChildren, children, isleaf, NoChildren
using Random: Xoshiro

struct EPlain; a; b; end
struct EParam{T}; x::T; y::Vector{T}; end
mutable struct EMutable; a; end
struct EEmpty end
struct ESubset; a; b; c; end
@functor ESubset (a, c)
struct ENone; a; end
@functor ENone ()
struct ELeaf; a; end
@leaf ELeaf
struct EOneArg; a; b; end
Functors.functor(x::EOneArg) = (; b = x.b), y -> EOneArg(x.a, y.b)
struct EChildren; a; b; end
Functors.children(x::EChildren) = (x.a,)
struct EIsLeaf; a; end
Functors.isleaf(::EIsLeaf) = true
struct ENotLeaf; end
Functors.isleaf(::ENotLeaf) = false
struct EFlex; a; b; params; end
@flexiblefunctor EFlex params
struct ELater; a; b; end
struct EFresh{T}; a::T; b; end

# What `erased_children(x)` should return, built from `children(x)`:
function erased_reference(x)
  ch = children(x)
  ch === NoChildren() && return nothing
  return vec(collect(Any, keys(ch))), vec(collect(Any, values(ch)))
end

function erased_agrees(x)
  ec, ref = erased_children(x), erased_reference(x)
  same = ref === nothing ? ec === nothing :
    ec isa ErasedChildren && isequal(keys(ec), ref[1]) &&
    length(ec) == length(ref[2]) && all(map(===, values(ec), ref[2]))
  return same && erased_isleaf(x) === isleaf(x)
end

@testset "erased_children & erased_isleaf agree with children & isleaf" begin
  objs = Any[
    EPlain(1, [2.0, 3.0]), EParam(1.0, [2.0]), EMutable(EPlain(1, 2)), EEmpty(),
    ESubset(1, 2, 3), ENone(1), ELeaf([1.0]), EOneArg(1, 2), EChildren(1, 2),
    EIsLeaf([1.0]), ENotLeaf(), EFlex(1, 2, (:a,)), let y = 2; z -> z + y end, sin,
    (), (1, [2.0]), (;), (a = 1, b = (2, 3)),
    Any[], Any[1, "two"], Any[1 2; 3 4], [EPlain(1, 2), EPlain(3, 4)], SA[EPlain(1, 2)],
    [1.0, 2.0], [1 2; 3 4], SA[1.0, 2.0], [1.0 2.0; 3.0 4.0]', transpose([1.0, 2.0]),
    PermutedDimsArray([1.0 2.0; 3.0 4.0], (2, 1)), Any[[1.0]]',
    Dict(:a => 1, :b => [2.0]), OrderedDict("x" => 1, "y" => [2.0]), Set([1, 2]), OrderedSet([:a, :b]),
    1, 2.0, 1 + 2im, 1.0 ± 0.1, "str", 'c', :sym, nothing, missing, Int, Vector,
    r"re", match(r"e", "re"), Xoshiro(1),
  ]
  VERSION >= v"1.12-" && push!(objs, Base.Fix1(+, 1))
  @test filter(!erased_agrees, objs) == []
  @test values(erased_children(EPlain(1, 2))) == [1, 2]
  @test keys(erased_children(Any[1 2; 3 4])) == vec(CartesianIndices((2, 2)))
end

@testset "erased_children notices methods defined after a first call" begin
  x = ELater(1, 2)
  @test keys(erased_children(x)) == [:a, :b]
  @test !erased_isleaf(x)
  @eval Functors.functor(::Type{<:ELater}, x) = (; b = x.b), y -> ELater(x.a, y.b)
  @test keys(Base.invokelatest(erased_children, x)) == [:b]
  @eval Functors.isleaf(::ELater) = true
  @test Base.invokelatest(erased_isleaf, x)
end

@testset "erased_children compiles nothing for a type with the default functor" begin
  x = EFresh(1.0, :b)
  @test keys(erased_children(x)) == [:a, :b]
  @test !erased_isleaf(x)
  # `which` may create a MethodInstance, but without compiled code:
  compiled_for_EFresh(f) = any(methods(f)) do m
    any(Base.specializations(m)) do mi
      mi !== nothing && isdefined(mi, :cache) && occursin("EFresh", string(mi.specTypes))
    end
  end
  @test !compiled_for_EFresh(Functors.functor)
  @test !compiled_for_EFresh(Functors.children)
  @test !compiled_for_EFresh(Functors.isleaf)
end
