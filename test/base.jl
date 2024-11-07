@testset "Numbers are leaves" begin
  @test Functors.isleaf(1)
  @test Functors.isleaf(1.0)
  @test Functors.isleaf(1im)
  @test Functors.isleaf(1//2)
  @test Functors.isleaf(1.0 + 2.0im)
end

@testset "RefValue" begin
  @test fmap(sqrt, Ref(16))[] == 4.0
  @test fmap(sqrt, Ref(16)) isa Ref
  @test fmapstructure(sqrt, Ref(16)) === (x = 4.0,)

  x = Ref(13)
  p, re = Functors.functor(x)
  @test p == (x = 13,)
  @test re(p) isa Base.RefValue{Int}

  x2 = (a = x, b = [7, x, nothing], c = (7, nothing, Ref(13)))
  y2 = fmap(identity, x2)
  @test x2.a !== y2.a  # it's a new Ref
  @test y2.a === y2.b[2]  # relation is maintained
  @test y2.a !== y2.c[3]  # no new relation created

  x3 = Ref([3.14])
  f3 = [Foo(x3, x), x3, x]
  @test f3[1].x === f3[2]
  y3 = fmapstructure(identity, f3)  # replaces mutable with immutable
  @test y3[1].x === y3[2]
  @test y3[1].x.x === y3[2].x
  z3 = fmapstructure(identity, y3)
  @test z3[1].x === z3[2]
  @test z3[1].x.x === z3[2].x
end

@testset "ComposedFunction" begin
  f1 = Foo(1.1, 2.2)
  f2 = Bar(3.3)
  @test Functors.functor(f1 ∘ f2)[1] == (outer = f1, inner = f2)
  @test Functors.functor(f1 ∘ f2)[2]((outer = f1, inner = f2)) == f1 ∘ f2
  @test fmap(x -> x + 10, f1 ∘ f2) == Foo(11.1, 12.2) ∘ Bar(13.3)
end

@testset "Pair, Fix12" begin
    @test fmap(sqrt, 4 => 9) === (2.0 => 3.0)

    exclude = x -> x isa Number
    @test fmap(sqrt, Base.Fix1(/, 4); exclude)(10) == 0.2
    @test fmap(sqrt, Base.Fix2(/, 4); exclude)(10) == 5.0
end

@testset "BroadcastFunction" begin
  f = Bar(3.3)
  bf = Base.Broadcast.BroadcastFunction(f)
  @test Functors.functor(bf)[1] == (f = f,)
  @test Functors.functor(bf)[2]((f = f,)) == bf
  @test fmap(x -> x + 10, bf) == Base.Broadcast.BroadcastFunction(Bar(13.3))
end

@testset "Returns" begin
  ret = Returns([0, pi, 2pi])
  @test Functors.functor(ret)[1] == (value = [0, pi, 2pi],)
  @test Functors.functor(ret)[2]((value = 1:3,)) === Returns(1:3)
end

@testset "Splat" begin
  ret = Base.splat(Returns([0, pi, 2pi]))
  @test Functors.functor(ret)[1].f.value == [0, pi, 2pi]
  @test Functors.functor(ret)[2]((f = sin,)) === Base.splat(sin)
end

@testset "LinearAlgebra containers" begin
  @test fmapstructure(identity, [1,2,3]') == (parent = [1, 2, 3],)
  @test fmapstructure(identity, transpose([1,2,3])) == (parent = [1, 2, 3],)

  CNT = Ref(0)
  fv(x::Vector) = (CNT[]+=1; 10v)

  v = [1,2,3]
  nt = fmap(fv, (a=v, b=v', c=transpose(v), d=[1,2,3]'))

  @test nt.a === adjoint(nt.b)  # does not break tie
  @test nt.a === transpose(nt.c)

  @test CNT[] == 2
  @test nt.a == adjoint(nt.d)  # does not create a new tie
  @test nt.a !== adjoint(nt.d)

  @test nt.b isa Adjoint
  @test nt.c isa Transpose

  x = [1,2,3]'
  xs = fmapstructure(identity, x)  # check it digests this, e.g. structural gradient representation
  @test Functors.functor(typeof(x), xs) == Functors.functor(x)  # (no real need for [2] types to match)

  x = transpose([1 2; 3 4])
  yt = transpose([5 6; 7 8])
  ym = Matrix(yt)  # check it digests this, e.g. simplest Matrix gradient
  @test Functors.functor(typeof(x), yt)[1].parent == Functors.functor(typeof(x), ym)[1].parent

  ybc = Broadcast.broadcasted(+, ym, 9)  # check it digests this, as Optimisers.jl makes these
  collect(ybc) isa Vector
  zbc = Functors.functor(typeof(x), ybc)[1].parent
  @test zbc .+ 0 == Functors.functor(typeof(x), ym .+ 9)[1].parent

  # Similar checks for Adjoint. 
  x = adjoint([1 2im 3; 4im 5 6im])
  yt = adjoint([7im 8 9; 0 im 2])
  ym = Matrix(yt)
  @test Functors.functor(typeof(x), yt)[1].parent == Functors.functor(typeof(x), ym)[1].parent

  ybc = Broadcast.broadcasted(+, ym, [11im, 12, im])
  collect(ybc) isa Vector
  zbc = Functors.functor(typeof(x), ybc)[1].parent
  @test zbc .+ 0 == Functors.functor(typeof(x), ym .+ [11im, 12, im])[1].parent
end

@testset "PermutedDimsArray" begin
  @test fmapstructure(identity, PermutedDimsArray([1 2; 3 4], (2,1))) == (parent = [1 2; 3 4],)
  @test fmap(exp, PermutedDimsArray([1 2; 3 4], (2,1))) isa PermutedDimsArray{Float64}
end

@testset "Iterators" begin
    exclude = x -> x isa Array

    x = fmap(complex, Iterators.map(sqrt, [1,2,3]); exclude)  # Base.Generator
    @test x.iter isa Vector{<:Complex}
    @test collect(x) isa Vector{<:Complex}

    x = fmap(complex, Iterators.accumulate(/, [1,2,3]); exclude)
    @test x.itr isa Vector{<:Complex}
    @test collect(x) isa Vector{<:Complex}

    x = fmap(complex, Iterators.cycle([1,2,3]))
    @test x.xs isa Vector{<:Complex}
    @test first(x) isa Complex

    x = fmap(complex, Iterators.drop([1,2,3], 1); exclude)
    @test x.xs isa Vector{<:Complex}
    @test collect(x) isa Vector{<:Complex}


    x = fmap(complex, Iterators.drop([1,2,3], 1); exclude)
    @test x.xs isa Vector{<:Complex}
    @test collect(x) isa Vector{<:Complex}

    x = fmap(float, Iterators.dropwhile(<(2), [1,2,3]); exclude)
    @test x.xs isa Vector{Float64}
    @test collect(x) isa Vector{Float64}

    x = fmap(complex, enumerate([1,2,3]))
    @test first(x) === (1, 1+0im)

    x = fmap(float, Iterators.filter(<(3), [1,2,3]); exclude)
    @test collect(x) isa Vector{Float64}

    x = fmap(complex, Iterators.flatten(([1,2,3], [4,5])))
    @test collect(x) isa Vector{<:Complex}

    x = fmap(complex, Iterators.partition([1,2,3],2); exclude)
    @test first(x) isa AbstractVector{<:Complex}

    x = fmap(complex, Iterators.product([1,2,3],[4,5]))
    @test first(x) === (1 + 0im, 4 + 0im)

    x = fmap(complex, Iterators.repeated([1,2,3], 4); exclude)  # Iterators.Take{Iterators.Repeated}
    @test first(x) isa Vector{<:Complex}

    x = fmap(complex, Iterators.rest([1,2,3], 2); exclude)
    @test collect(x) isa Vector{<:Complex}

    x = fmap(complex, Iterators.reverse([1,2,3]))
    @test collect(x) isa Vector{<:Complex}

    x = fmap(float, Iterators.takewhile(<(2), [1,2,3]); exclude)
    @test collect(x) isa Vector{Float64}

    x = fmap(complex, zip([1,2,3], [4,5]))
    @test x.is[1] isa Vector{<:Complex}
    @test collect(x) isa Vector{<:Tuple{Complex, Complex}}
end

@testset "AbstractString is leaf" begin
  struct DummyString <: AbstractString
    str::String
  end
  s = DummyString("hello")
  @test Functors.isleaf(s)
end
@testset "AbstractPattern is leaf" begin
  struct DummyPattern <: AbstractPattern
    pat::Regex
  end
  p = DummyPattern(r"\d+")
  @test Functors.isleaf(p)
  @test Functors.isleaf(r"\d+")  
end
@testset "AbstractChar is leaf" begin
  struct DummyChar <: AbstractChar
    ch::Char
  end
  c = DummyChar('a')
  @test Functors.isleaf(c)
  @test Functors.isleaf('a')
end

@testset "AbstractDict is functor" begin
  od = OrderedDict(1 => 1, 2 => 2)
  @test !Functors.isleaf(od)
  od2 = fmap(x -> 2x, od)
  @test od2 isa OrderedDict
  @test od2[1] == 2
  @test od2[2] == 4
end

@testset "Types are leaves" begin
  @test Functors.isleaf(Int)
  @test Functors.isleaf(Array)
  @test fmap(identity, (1,Int,Ref,Array,5)) == (1,Int,Ref,Array,5)
end

