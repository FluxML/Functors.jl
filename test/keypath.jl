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

    @testset "getkeypath" begin
        x = Dict(:a => 3, :b => Dict(:c => 4, "d" => [5, 6, 7]))
        @test getkeypath(x, KeyPath(:a)) == 3
        @test getkeypath(x, KeyPath(:b, :c)) == 4
        @test getkeypath(x, KeyPath(:b, "d", 2)) == 6
   
        @testset "@functor defines keypath indexing" begin
            struct Tkp
                a
                b
                c
            end
            @functor Tkp
                
            x = Tkp(3, Tkp(4, 5, 6), (7, 8))
            kp = KeyPath(:b, :b, 1)
            @test x[kp] == getkeypath(x, kp)
            @test x[KeyPath(:c, :2)] == 8
        end
    end
end
