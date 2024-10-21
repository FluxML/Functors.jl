using Functors, Test
using Zygote
using LinearAlgebra
using StaticArrays
using OrderedCollections: OrderedDict

@testset "Functors.jl" begin
  include("basics.jl")
  include("base.jl")
  include("keypath.jl")
  include("flexiblefunctors.jl")
end
