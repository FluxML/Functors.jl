
struct Foo; x; y; end
@functor Foo

struct Bar; x; end
@functor Bar

struct OneChild3; x; y; z; end
@functor OneChild3 (y,)

struct NoChildren2; x; y; end

@static if VERSION >= v"1.6"
  @testset "ComposedFunction" begin
    f1 = Foo(1.1, 2.2)
    f2 = Bar(3.3)
    @test Functors.functor(f1 ∘ f2)[1] == (outer = f1, inner = f2)
    @test Functors.functor(f1 ∘ f2)[2]((outer = f1, inner = f2)) == f1 ∘ f2
    @test fmap(x -> x + 10, f1 ∘ f2) == Foo(11.1, 12.2) ∘ Bar(13.3)
  end
end

###
### Basic functionality
###

@testset "Nested" begin
  model = Bar(Foo(1, [1, 2, 3]))

  model′ = fmap(float, model)

  @test model.x.y == model′.x.y
  @test model′.x.y isa Vector{Float64}
end

@testset "Exclude" begin
  f(x::AbstractArray) = x
  f(x::Char) = 'z'

  x = ['a', 'b', 'c']
  @test fmap(f, x)  == ['z', 'z', 'z']
  @test fmap(f, x; exclude = x -> x isa AbstractArray) == x

  x = (['a', 'b', 'c'], ['d', 'e', 'f'])
  @test fmap(f, x)  == (['z', 'z', 'z'], ['z', 'z', 'z'])
  @test fmap(f, x; exclude = x -> x isa AbstractArray) == x
end

@testset "Property list" begin
  model = OneChild3(1, 2, 3)
  model′ = fmap(x -> 2x, model)
  
  @test (model′.x, model′.y, model′.z) == (1, 4, 3)
end

@testset "cache" begin
  shared = [1,2,3]
  m1 = Foo(shared, Foo([1,2,3], Foo(shared, [1,2,3])))
  m1f = fmap(float, m1)
  @test m1f.x === m1f.y.y.x
  @test m1f.x !== m1f.y.x
  m1p = fmapstructure(identity, m1; prune = nothing)
  @test m1p == (x = [1, 2, 3], y = (x = [1, 2, 3], y = (x = nothing, y = [1, 2, 3])))

  # A non-leaf node can also be repeated:
  m2 = Foo(Foo(shared, 4), Foo(shared, 4))
  @test m2.x === m2.y
  m2f = fmap(float, m2)
  @test m2f.x.x === m2f.y.x
  m2p = fmapstructure(identity, m2; prune = Bar(0))
  @test m2p == (x = (x = [1, 2, 3], y = 4), y = Bar(0))

  # Repeated isbits types should not automatically be regarded as shared:
  m3 = Foo(Foo(shared, 1:3), Foo(1:3, shared))
  m3p = fmapstructure(identity, m3; prune = 0)
  @test m3p.y.y == 0
  @test_broken m3p.y.x == 1:3
end

###
### Extras
###

@testset "Walk" begin
  model = Foo((0, Bar([1, 2, 3])), [4, 5])

  model′ = fmapstructure(identity, model)
  @test model′ == (; x=(0, (; x=[1, 2, 3])), y=[4, 5])
end

@testset "fcollect" begin
  m1 = [1, 2, 3]
  m2 = 1
  m3 = Foo(m1, m2)
  m4 = Bar(m3)
  @test all(fcollect(m4) .=== [m4, m3, m1, m2])
  @test all(fcollect(m4, exclude = x -> x isa Array) .=== [m4, m3, m2])
  @test all(fcollect(m4, exclude = x -> x isa Foo) .=== [m4])

  m1 = [1, 2, 3]
  m2 = Bar(m1)
  m0 = NoChildren2(:a, :b)
  m3 = Foo(m2, m0)
  m4 = Bar(m3)
  @test all(fcollect(m4) .=== [m4, m3, m2, m1, m0])

  m1 = [1, 2, 3]
  m2 = [1, 2, 3]
  m3 = Foo(m1, m2)
  @test all(fcollect(m3) .=== [m3, m1, m2])
end

###
### Vararg forms
###

@testset "fmap(f, x, y)" begin
  m1 = (x = [1,2], y = 3)
  n1 = (x = [4,5], y = 6)
  @test fmap(+, m1, n1) == (x = [5, 7], y = 9)

  # Reconstruction type comes from the first argument
  foo1 = Foo([7,8], 9)
  @test fmap(+, m1, foo1) == (x = [8, 10], y = 12)
  @test fmap(+, foo1, n1) isa Foo
  @test fmap(+, foo1, n1).x == [11, 13]

  # Mismatched trees should be an error
  m2 = (x = [1,2], y = (a = [3,4], b = 5))
  n2 = (x = [6,7], y = 8)
  @test_throws Exception fmap(first∘tuple, m2, n2)
  @test_throws Exception fmap(first∘tuple, m2, n2)

  # The cache uses IDs from the first argument
  shared = [1,2,3]
  m3 = (x = shared, y = [4,5,6], z = shared)
  n3 = (x = shared, y = shared, z = [7,8,9])
  @test fmap(+, m3, n3) == (x = [2, 4, 6], y = [5, 7, 9], z = [2, 4, 6])
  z3 = fmap(+, m3, n3)
  @test z3.x === z3.z
end

@testset "old test update.jl" begin
  struct M{F,T,S}
    σ::F
    W::T
    b::S
  end

  @functor M

  (m::M)(x) = m.σ.(m.W * x .+ m.b)

  m = M(identity, ones(Float32, 3, 4), zeros(Float32, 3))
  x = ones(Float32, 4, 2)
  m̄, _ = gradient((m,x) -> sum(m(x)), m, x)
  m̂ = Functors.fmap(m, m̄) do x, y
    isnothing(x) && return y
    isnothing(y) && return x
    x .- 0.1f0 .* y
  end

  @test m̂.W ≈ fill(0.8f0, size(m.W))
  @test m̂.b ≈ fill(-0.2f0, size(m.b))
end

###
### FlexibleFunctors.jl
###

struct FFoo
  x
  y
  p
end
@flexiblefunctor FFoo p

struct FBar
  x
  p
end
@flexiblefunctor FBar p

struct FOneChild4
  x
  y
  z
  p
end
@flexiblefunctor FOneChild4 p

@testset "Flexible Nested" begin
  model = FBar(FFoo(1, [1, 2, 3], (:y, )), (:x,))

  model′ = fmap(float, model)

  @test model.x.y == model′.x.y
  @test model′.x.y isa Vector{Float64}
end

@testset "Flexible Walk" begin
  model = FFoo((0, FBar([1, 2, 3], (:x,))), [4, 5], (:x, :y))

  model′ = fmapstructure(identity, model)
  @test model′ == (; x=(0, (; x=[1, 2, 3])), y=[4, 5])

  model2 = FFoo((0, FBar([1, 2, 3], (:x,))), [4, 5], (:x,))

  model2′ = fmapstructure(identity, model2)
  @test model2′ == (; x=(0, (; x=[1, 2, 3])))
end

@testset "Flexible Property list" begin
  model = FOneChild4(1, 2, 3, (:x, :z))
  model′ = fmap(x -> 2x, model)

  @test (model′.x, model′.y, model′.z) == (2, 2, 6)
end

@testset "Flexible fcollect" begin
  m1 = 1
  m2 = [1, 2, 3]
  m3 = FFoo(m1, m2, (:y, ))
  m4 = FBar(m3, (:x,))
  @test all(fcollect(m4) .=== [m4, m3, m2])
  @test all(fcollect(m4, exclude = x -> x isa Array) .=== [m4, m3])
  @test all(fcollect(m4, exclude = x -> x isa FFoo) .=== [m4])

  m0 = NoChildren2(:a, :b)
  m1 = [1, 2, 3]
  m2 = FBar(m1, ())
  m3 = FFoo(m2, m0, (:x, :y,))
  m4 = FBar(m3, (:x,))
  @test all(fcollect(m4) .=== [m4, m3, m2, m0])
end
