using Functors, Test
using Zygote

@testset verbose=true "Functors.jl" begin

  include("basics.jl")
  include("base.jl")
  include("vec.jl")

  include("update.jl")

  if VERSION < v"1.6" # || VERSION > v"1.7-"
    @warn "skipping doctests, on Julia $VERSION"
  else
    using Documenter
    @testset "doctests" begin
      DocMeta.setdocmeta!(Functors, :DocTestSetup, :(using Functors); recursive=true)
      doctest(Functors, manual=true)
    end
  end
end
