module Functors

include("functor.jl")
export @functor, @flexiblefunctor, fmap, fmapstructure, fcollect

include("vec.jl")
export fvec, fcopy, fview

include("base.jl")

end # module
