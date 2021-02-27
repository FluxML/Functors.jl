using Functors, Test

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

@testset "Nested" begin
  model = Bar(Foo(1, [1, 2, 3]))

  model′ = fmap(float, model)

  @test model.x.y == model′.x.y
  @test model′.x.y isa Vector{Float64}
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
  @test all(fcollect(m4) .=== [m4, m3, m1, m2])
  @test all(fcollect(m4, exclude = x -> x isa Array) .=== [m4, m3, m2])
  @test all(fcollect(m4, exclude = x -> x isa Foo) .=== [m4])

  m1 = [1, 2, 3]
  m2 = Bar(m1)
  m0 = NoChildren(:a, :b)
  m3 = Foo(m2, m0)
  m4 = Bar(m3)
  println(fcollect(m4))
  @test all(fcollect(m4) .=== [m4, m3, m2, m1, m0])
end
