using Functors, Test
using Zygote

@testset "Functors.jl" begin

  include("basics.jl")
  include("update.jl")
end
