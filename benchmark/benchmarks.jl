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
    
    return suite
end

setup_fmap_bench!(SUITE)

# results = BenchmarkTools.run(SUITE; verbose=true)

# filename = joinpath(@__DIR__, "benchmarks_old.json")
# BenchmarkTools.save(filename, median(results))


# # Plot
# using StatsPlots, BenchmarkTools
# plot(results["fmap"], yaxis=:log10, st=:violin)

# # Compare
# old_results = BenchmarkTools.load("benchmarks.json")[1]
# judge(median(results), old_results)
