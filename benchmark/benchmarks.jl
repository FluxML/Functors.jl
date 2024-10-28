# We run the benchmarks using AirspeedVelocity.jl

# To run benchmarks locally, first install AirspeedVelocity.jl:
# julia> using Pkg; Pkg.add("AirspeedVelocity"); Pkg.build("AirspeedVelocity")
# and make sure .julia/bin is in your PATH.

# Then commit the changes and run:
# $ benchpkg Functors --rev=mybranch,master --bench-on=mybranch 


using BenchmarkTools: BenchmarkTools, BenchmarkGroup, @benchmarkable, @btime, @benchmark, judge
using ConcreteStructs: @concrete
using Flux: Dense, Chain
using LinearAlgebra: BLAS
using Functors
using Statistics: median

const SUITE = BenchmarkGroup()
const BENCHMARK_CPU_THREADS = Threads.nthreads()
BLAS.set_num_threads(BENCHMARK_CPU_THREADS)


@concrete struct A
    w
    b
    σ
end

struct B
    w
    b
    σ
end

function setup_fmap_bench!(suite)
    a = A(rand(5,5), rand(5), tanh)
    suite["fmap"]["concrete struct"] = @benchmarkable fmap(identity, $a)

    a = B(rand(5,5), rand(5), tanh)
    suite["fmap"]["non-concrete struct"] = @benchmarkable fmap(identity, $a)
    
    a = Dense(5, 5, tanh)
    suite["fmap"]["flux dense"] = @benchmarkable fmap(identity, $a)

    a = Chain(Dense(5, 5, tanh), Dense(5, 5, tanh))
    suite["fmap"]["flux dense chain"] = @benchmarkable fmap(identity, $a)
    
    nt = (layers=(w= rand(5,5), b=rand(5), σ=tanh),)
    suite["fmap"]["named tuple"] = @benchmarkable fmap(identity, $nt)

    return suite
end

setup_fmap_bench!(SUITE)

## AirspeedVelocity.jl will automatically run the benchmarks and save the results
# results = BenchmarkTools.run(SUITE; verbose=true)
