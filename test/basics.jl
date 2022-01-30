struct Foo
  x
  y
end
@functor Foo

struct Bar
  x
end
@functor Bar

struct Baz
  x
  y
  z
end
@functor Baz (y,)

struct NoChildren 
  x
  y
end

@static if VERSION >= v"1.6"
  @testset "ComposedFunction" begin
    f1 = Foo(1.1, 2.2)
    f2 = Bar(3.3)
    @test Functors.functor(f1 ∘ f2)[1] == (outer = f1, inner = f2)
    @test Functors.functor(f1 ∘ f2)[2]((outer = f1, inner = f2)) == f1 ∘ f2
    @test fmap(x -> x + 10, f1 ∘ f2) == Foo(11.1, 12.2) ∘ Bar(13.3)
  end
end

@testset "Folds" begin
  arrays = ntuple(i -> [i], 3)
  model = Foo(
    Foo(arrays[1], arrays[2]),
    Foo(arrays[3], arrays[1])
  )

  total = Ref(0)
  Functors.fmap(model, cache = true) do x
    total[] += only(x)
  end
  @test total[] == 6

  total = Ref(0)
  Functors.fmap(model, cache = false) do x
    total[] += only(x)
  end
  @test total[] == 7
end

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

@testset "Walk" begin
  model = Foo((0, Bar([1, 2, 3])), [4, 5])

  model′ = fmapstructure(identity, model)
  @test model′ == (; x=(0, (; x=[1, 2, 3])), y=[4, 5])
end

@testset "Property list" begin
  model = Baz(1, 2, 3)
  model′ = fmap(x -> 2x, model)
  
  @test (model′.x, model′.y, model′.z) == (1, 4, 3)
end

@testset "fcollect" begin
  m1 = [1, 2, 3]
  m2 = 1
  m3 = Foo(m1, m2)
  m4 = Bar(m3)
  @test all(fcollect(m4) .=== [m1, m2, m3, m4])
  @test all(fcollect(m4, exclude = x -> x isa Array) .=== [m2, m3, m4])
  @test all(fcollect(m4, exclude = x -> x isa Foo) .=== [m4])

  m1 = [1, 2, 3]
  m2 = Bar(m1)
  m0 = NoChildren(:a, :b)
  m3 = Foo(m2, m0)
  m4 = Bar(m3)
  @test all(fcollect(m4) .=== [m1, m2, m0, m3, m4])

  m1 = [1, 2, 3]
  m2 = [1, 2, 3]
  m3 = Foo(m1, m2)
  @test all(fcollect(m3) .=== [m1, m2, m3])
end

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

struct FBaz
  x
  y
  z
  p
end
@flexiblefunctor FBaz p

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
  model = FBaz(1, 2, 3, (:x, :z))
  model′ = fmap(x -> 2x, model)

  @test (model′.x, model′.y, model′.z) == (2, 2, 6)
end

@testset "Flexible fcollect" begin
  m1 = 1
  m2 = [1, 2, 3]
  m3 = FFoo(m1, m2, (:y, ))
  m4 = FBar(m3, (:x,))
  @test all(fcollect(m4) .=== [m2, m3, m4])
  @test all(fcollect(m4, exclude = x -> x isa Array) .=== [m3, m4])
  @test all(fcollect(m4, exclude = x -> x isa FFoo) .=== [m4])

  m0 = NoChildren(:a, :b)
  m1 = [1, 2, 3]
  m2 = FBar(m1, ())
  m3 = FFoo(m2, m0, (:x, :y,))
  m4 = FBar(m3, (:x,))
  @test all(fcollect(m4) .=== [m2, m0, m3, m4])
end
