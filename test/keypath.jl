@testset "KeyPath" begin
    kp = KeyPath(:a, 3, :b, 4)
    @test (kp...,) === (:a, 3, :b, 4)
    @test length(kp) == 4
    @test kp[1] == :a
    @test kp[2] == 3
    @test kp[3] == :b
    @test kp[4] == 4

    kp2 = KeyPath(:a, kp, :c, 5)
    @test (kp2...,) === (:a, :a, 3, :b, 4, :c, 5)

    kp3 = KeyPath(kp, kp2)
    @test (kp3...,) === (:a, 3, :b, 4, :a, :a, 3, :b, 4, :c, 5)    

    kp0 = KeyPath()
    @test (kp0...,) === ()
end
