using Zygote, ChainRulesCore
using Functors, Flux
using Optimisers
using BenchmarkTools


function loss1(m)
    ls = 0f0
    for l in Functors.fleaves(m)
        if l isa AbstractArray{<:Number}
            ls += sum(l)
        end
    end
    return ls
end

function loss2(m)
    sum(sum(l) for l in Functors.fleaves(m) if l isa AbstractArray{<:Number})
end

function loss3(m)
    sum([sum(l) for l in Functors.fleaves(m) if l isa AbstractArray{<:Number}])
end


function perf()
    m = Chain(Dense(128 => 128, relu), BatchNorm(3), Dense(128 => 10))
    @btime gradient(loss1, $m)[1]
    @btime gradient(loss2, $m)[1]
    @btime gradient(loss3, $m)[1]
end

perf();
perf();
perf();