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

    struct Tkp
        a
        b
        c
    end

    function Base.getproperty(x::Tkp, k::Symbol)
        if k in fieldnames(Tkp)
            return getfield(x, k)
        elseif k === :ab
            return "ab"
        else        
            error()
        end
    end

    Base.propertynames(::Tkp) = (:a, :b, :c, :ab)

    @testset "getkeypath" begin
        x = Dict(:a => 3, :b => Dict(:c => 4, "d" => [5, 6, 7]))
        @test getkeypath(x, KeyPath(:a)) == 3
        @test getkeypath(x, KeyPath(:b, :c)) == 4
        @test getkeypath(x, KeyPath(:b, "d", 2)) == 6

        x = Tkp(3, Tkp(4, 5, (6, 7)), 8)
        kp = KeyPath(:b, :c, 2)
        @test getkeypath(x, kp) == 7

        x = [(a=1,) (b=2,)]
        @test getkeypath(x, KeyPath(CartesianIndex(1, 1), :a)) == 1
        @test getkeypath(x, KeyPath(CartesianIndex(1, 2), :b)) == 2

        @testset "access through getproperty" begin
            x = Tkp(3, Dict(:c => 4, :d => 5), 6);

            @test getkeypath(x, KeyPath(:ab)) == "ab"
            @test getkeypath(x, KeyPath(:b, :c)) == 4
        end
    end

    @testset "setkeypath!" begin
        x = Dict(:a => 3, :b => Dict(:c => 4, "d" => [5, 6, 7]))
        setkeypath!(x, KeyPath(:a), 4)
        @test x[:a] == 4
        setkeypath!(x, KeyPath(:b, "d", 1), 17)
        @test x[:b]["d"][1] == 17
        setkeypath!(x, KeyPath(:b, "d"), [0])
        @test x[:b]["d"] == [0]
        
        x = Tkp(3, Tkp(4, 5, [6, 7]), 8)
        kp = KeyPath(:b, :c, 2)
        setkeypath!(x, kp, 17)
        @test x.b.c[2] == 17

        x = [(a=1,) (b=2,)]
        setkeypath!(x, KeyPath(CartesianIndex(1, 2)), (c=3,))
        @test x[2] == (c=3,)
    end

    @testset "haskeypath" begin
        x = Dict(:a => 3, :b => Dict(:c => 4, "d" => [5, 6, 7]))
        @test haskeypath(x, KeyPath(:a))
        @test haskeypath(x, KeyPath(:b, :c))
        @test haskeypath(x, KeyPath(:b, "d", 2))
        @test !haskeypath(x, KeyPath(:b, "d", 4))
        @test !haskeypath(x, KeyPath(:b, "e"))

        x = [(a=1,) (b=2,)]
        @test haskeypath(x, KeyPath(CartesianIndex(1, 1)))
        @test haskeypath(x, KeyPath(CartesianIndex(1, 2)))
        @test !haskeypath(x, KeyPath(CartesianIndex(1, 3)))

        @testset "access through getproperty" begin
            x = Tkp(3, Dict(:c => 4, :d => 5), 6);

            @test haskeypath(x, KeyPath(:ab))
            @test haskeypath(x, KeyPath(:b, :c))
            @test !haskeypath(x, KeyPath(:b, :e))
        end
    end
end
