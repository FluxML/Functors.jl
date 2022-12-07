
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
  
    m0 = NoChild2(:a, :b)
    m1 = [1, 2, 3]
    m2 = FBar(m1, ())
    m3 = FFoo(m2, m0, (:x, :y,))
    m4 = FBar(m3, (:x,))
    @test all(fcollect(m4) .=== [m4, m3, m2, m0])
  end
  