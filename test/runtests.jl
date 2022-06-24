using Functors, Test
using Zygote
using LinearAlgebra

@testset "Functors.jl" begin

  include("basics.jl")
  include("base.jl")

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
