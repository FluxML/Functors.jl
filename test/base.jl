@testset "Base" begin
    @testset "RefValue" begin
        x = Ref(1)
        p, re = Functors.functor(x)
        @test p == (x = 1,)
        @test re(p) isa Base.RefValue{Int}
    end
end
