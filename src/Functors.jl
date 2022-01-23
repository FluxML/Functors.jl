module Functors

include("functor.jl")
export @functor, @flexiblefunctor, fmap, fmapstructure, fcollect

include("vec.jl")
export fvec, fcopy

include("base.jl")

end # module
