@testset "inferred" begin
    r = [1,2]
    x = (a = r, b = 3, c =(4, (d=5, e=r)))
    y = @inferred(fmap(float, x))
    @test y.a === y.c[2].e
end
