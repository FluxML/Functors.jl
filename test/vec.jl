
using Functors
using Functors: flatlength, flatgrad!

@testset "fvec + flatlength + fcopy" begin
  @testset "basics" begin
    @test fvec([1,2,3]) == [1,2,3]
    @test fvec(([1,2], [3,4])) == [1,2,3,4]
    @test fvec((x=[[1,2], [3,4]],)) == [1,2,3,4]
    @test fvec((x=[1,2], y=(nothing, transpose([3,4]), 5, sin))) == [1,2,3,4]
    @test fvec((x=1, y=2, z=error)) == []
    @test fvec(([1,2], [3im,4im])) == [1,2,3im,4im]
    @test fvec(([1,2], [true, false])) == [1,2]

    @test flatlength([1,2,3]) == 3
    @test flatlength(([1,2], [3,4])) == 4
    @test flatlength(fvec((x=1, y=2, z=error))) == 0

    @test fcopy([1,2,3], [4,5,6]) == [4,5,6]
    @test fcopy(([1,2], [3,4]), [4,5,6,7]) == ([4,5], [6,7])
    @test fcopy((x=[1,2], y=(nothing, transpose([3,4]), 5, sin)), [6,7,8,9]) == (x = [6, 7], y = (nothing, [8 9], 5, sin))
    @test fcopy((x=1, y=2, z=error), []) == (x = 1, y = 2, z = error)

    @test fview([1,2,3], [4,5,6]) == [4,5,6]
    @test fview(([1,2], [3,4]), [4,5,6,7]) == ([4,5], [6,7])
    @test fview(([1,2], [3,4]), [4,5,6,7])[1] isa SubArray
  end
  @testset "tied parameters" begin
    twice = [1,2]
    @test fvec((twice, twice)) == [1,2]
    @test fvec((twice, twice, [1,2])) == [1,2,1,2]
    @test fvec((x=[3,4], y=(missing, twice), z=transpose(twice))) == [3,4,1,2]
    @test fvec((1:2, 1:2)) == [1,2,1,2]

    @test flatlength((twice, twice)) == 2
    @test flatlength((1:2, 1:2)) == 4

    @test fcopy((twice, twice), [3,4]) == ([3,4], [3,4])
    xyz = fcopy((x=[3,4], y=(missing, twice), z=transpose(twice)), [5,6,7,8])
    @test xyz.y[2] === xyz.z.parent
    xyz2 = fview((x=[3,4], y=(missing, twice), z=transpose(twice)), [5,6,7,8])
    @test xyz2.y[2] === xyz2.z.parent

    @test_throws ArgumentError fvec((twice, reshape(twice, 1, :)))

    @test_throws DimensionMismatch fcopy(([1,2], [3,4]), [4,5,6])
    @test_throws DimensionMismatch fcopy(([1,2], [3,4]), [4,5,6,7,8])
end

using Zygote

@testset "gradients" begin
  @testset "flatgrad!" begin
    @test flatgrad!(rand(4), ([1,2], [3,4]), ([5,6], [7,8])) == [5,6,7,8]
    @test flatgrad!(rand(4), ([1,2], [3,4]), ([5,6],)) == [5,6,0,0]
    @test flatgrad!(rand(4), (a=[1,2], b=3, c=[4,5]), (a=nothing, c=[10, 20])) == [0, 0, 10, 20]
  end
  @testset "lazy arrays"
    @test flatgrad!(rand(4), (a=0, b=transpose([1 2; 3 4])), (b=(parent=[5 6; 7 8],),)) == [5,7,6,8]
    @test flatgrad!(rand(4), (a=0, b=adjoint([1 2; 3 4])), (b=[5 6; 7 8],)) == [5,6,7,8]

    x = PermutedDimsArray(rand(Int8, 3,4,5), (3,1,2))
    @test flatgrad!(rand(3*4*5+2), (a=[1,2], x=x), (a=[10,20], x=(parent=x.parent,))) == vcat([10,20], vec(x.parent))
    @test flatgrad!(rand(3*4*5+2), (a=[1,2], x=x), (a=[10,20], x=x)) == vcat([10,20], vec(x.parent))

    y = Base.ReshapedArray(rand(Int8,3,4), (2,6), ())
    @test_broken false  # needs a test!
  end
  @testset "combined" begin
    for m in [
        ([1,2], [3,4])
        (a=0, b=[1,2], c=[3,4])
        (a=nothing, b=transpose([1 2; 3 4]))
        (a=(), b=adjoint([1,2,3]), c=[4])
      ]
      @show m
      @test gradient(v -> sum(abs2, fvec(fcopy(m, v))), [1,2,3,4]) == ([2,4,6,8],)
      @test gradient(v -> sum(abs2, fvec(fview(m, v))), [1,2,3,4]) == ([2,4,6,8],)
    end
    @test_broken false  # needs more!
  end
  @testset "tied" begin
    @test_broken false
  end
end
