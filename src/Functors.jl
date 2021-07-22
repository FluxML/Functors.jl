module Functors

using MacroTools

export @functor, @flexiblefunctor, fmap, fmapstructure, fcollect

include("functor.jl")

end # module
