@testset "Generalized fmap over equivalent functors" begin
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
