
@testset "RefValue" begin
    @test fmap(sqrt, Ref(16))[] == 4.0
    @test fmap(sqrt, Ref(16)) isa Ref
    @test fmapstructure(sqrt, Ref(16)) === (x = 4.0,)

    x = Ref(1)
    p, re = Functors.functor(x)
    @test p == (x = 1,)
    @test re(p) isa Base.RefValue{Int}
end

@testset "PermutedDimsArray" begin
    @test fmapstructure(identity, PermutedDimsArray([1 2; 3 4], (2,1))) == (parent = [1 2; 3 4],)
    @test fmap(exp, PermutedDimsArray([1 2; 3 4], (2,1))) isa PermutedDimsArray{Float64}
end

@testset "LinearAlgebra containers" begin
    @test fmapstructure(identity, [1,2,3]') == (parent = [1, 2, 3],)
    @test fmapstructure(identity, transpose([1,2,3])) == (parent = [1, 2, 3],)

    CNT = Ref(0)
    fv(x::Vector) = (CNT[]+=1; 10v)

    v = [1,2,3]
    nt = fmap(fv, (a=v, b=v', c=transpose(v), d=[1,2,3]'))

    @test nt.a === adjoint(nt.b)  # does not break tie
    @test nt.a === transpose(nt.c)

    @test CNT[] == 2
    @test nt.a == adjoint(nt.d)  # does not create a new tie
    @test nt.a !== adjoint(nt.d)
end

@testset "Iterators" begin
    @test fmapstructure(x -> x./2, Iterators.repeated([1,2,3], 4)) == (xs = (x = [0.5, 1.0, 1.5],),)
    @test fmap(float, Iterators.repeated(([1,2,3], [4,5,6]), 4)) isa Iterators.Take

    @test fmap(float, zip([1,2], [3,4])) isa Iterators.Zip
    @test first(fmap(float, zip([1,2], [3,4]))) === (1.0, 3.0)
end
