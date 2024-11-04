using Functors, Test
using Zygote
using LinearAlgebra
using StaticArrays
using OrderedCollections: OrderedDict
using Measurements: ±

@testset "Functors.jl" begin
  include("basics.jl")
  include("base.jl")
  include("keypath.jl")
  include("flexiblefunctors.jl")
  include("cache.jl")
end
