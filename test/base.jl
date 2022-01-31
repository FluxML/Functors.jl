
@testset "RefValue" begin
  @test fmap(sqrt, Ref(16))[] == 4.0
  @test fmap(sqrt, Ref(16)) isa Ref
  @test fmapstructure(sqrt, Ref(16)) === (x = 4.0,)

  x = Ref(1)
  p, re = Functors.functor(x)
  @test p == (x = 1,)
  @test re(p) isa Base.RefValue{Int}
end

@testset "ComposedFunction" begin
  f1 = Foo(1.1, 2.2)
  f2 = Bar(3.3)
  @test Functors.functor(f1 ∘ f2)[1] == (outer = f1, inner = f2)
  @test Functors.functor(f1 ∘ f2)[2]((outer = f1, inner = f2)) == f1 ∘ f2
  @test fmap(x -> x + 10, f1 ∘ f2) == Foo(11.1, 12.2) ∘ Bar(13.3)
end

@testset "PermutedDimsArray" begin
  @test fmapstructure(identity, PermutedDimsArray([1 2; 3 4], (2,1))) == (parent = [1 2; 3 4],)
  @test fmap(exp, PermutedDimsArray([1 2; 3 4], (2,1))) isa PermutedDimsArray{Float64}
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
