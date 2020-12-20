using Functors, Test

@testset "Nested" begin
  struct Foo
    x
    y
  end

  @functor Foo

  struct Bar
    x
  end

  @functor Bar

  model = Bar(Foo(1, [1, 2, 3]))

  model′ = fmap(float, model)

  @test model.x.y == model′.x.y
  @test model′.x.y isa Vector{Float64}
end

@testset "Property list" begin
  struct Baz
    x
    y
    z
  end
  
  @functor Baz (y,)
  
  model = Baz(1, 2, 3)
  model′ = fmap(x -> 2x, model)
  
  @test (model′.x, model′.y, model′.z) == (1, 4, 3)
end
