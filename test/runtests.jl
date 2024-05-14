using Functors, Test
using Zygote
using LinearAlgebra
using StaticArrays

@testset "Functors.jl" begin

  include("basics.jl")
  include("base.jl")
  include("keypath.jl")

end
