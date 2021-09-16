using Functors, Test

abstract type Expr end

struct Index <: Expr
    arg::Expr
    idx::Expr
end
@functor Index

struct Call <: Expr
    fn::Expr
    args::Vector{Expr}
end
Base.:(==)(c1::Call, c2::Call) = c1.fn == c2.fn && c1.args == c2.args
@functor Call

struct Unary <: Expr
    op::String
    arg::Expr
end
@functor Unary (arg,)

struct Binary <: Expr
    lhs::Expr
    op::String
    rhs::Expr
end
@functor Binary (lhs, rhs)

struct Paren <: Expr
    inner::Expr
end
@functor Paren

struct Ident <: Expr
    name::String
end
@functor Ident

struct Literal{T} <: Expr
    val::T
end
@functor Literal


@testset "cata" begin
    ten, add = Literal(10), Ident("add")
    call = Call(add, [ten, ten])

    @testset "converting to POJOs" begin
        expected = (fn = (;name="add"), args = [(;val=10), (;val=10)])
        @test Functors.cata(Functors.backing, call) == expected
    end

    @testset "roundtrip" begin
        @test Functors.cata(Functors.embed, call) == call
    end

    @testset "rfmap" begin
        f64(x) = x
        f64(x::Real) = Float64(x)

        expected = Call(Ident("add"), [Literal(10.), Literal(10.)])
        @test Functors.rfmap(f64, call) == expected
    end

    @testset "counting nodes" begin
        countnodes(e::Functor{Unary}) = 1 + e.arg
        countnodes(e::Functor{Binary}) = 1 + e.lhs + e.rhs
        countnodes(e::Functor{Call}) = 1 + e.fn + sum(e.args)
        countnodes(e::Functor{Index}) = 1 + e.arg + e.idx
        countnodes(e::Functor{Paren}) = 1 + e.inner
        countnodes(e::Functor{Literal}) = 1
        countnodes(e::Functor{Ident}) = 1
        countnodes(e) = e

        @test Functors.cata(countnodes, call) == 4
    end
        
    @testset "pretty-printing" begin
        prettyprint(l::Functor{Literal}) = repr(l.val)
        prettyprint(i::Functor{Ident}) = i.name
        prettyprint(c::Functor{Call}) = "$(c.fn)($(join(c.args, ",")))"
        prettyprint(i::Functor{Index}) = "$(i.arg)[$(i.idx)]"
        prettyprint(u::Functor{Unary}) = u.op * u.expr
        prettyprint(b::Functor{Binary}) = b.lhs * b.op * b.rhs
        prettyprint(p::Functor{Paren}) = "[$(p.inner)]"
        prettyprint(e) = e
        
        @test Functors.cata(prettyprint, call) == "add(10,10)"
    end
end

@testset "ana" begin
    function nested(n)
        go(m) = m == 0 ? Literal(n) : functor(Paren, m - 1)
        Functors.ana(go, n)
    end
    
    @test nested(3) == 3 |> Literal |> Paren |> Paren |> Paren
end

# @static if VERSION >= v"1.6"
#   @testset "ComposedFunction" begin
#     f1 = Foo(1.1, 2.2)
#     f2 = Bar(3.3)
#     @test Functors.functor(f1 ∘ f2)[1] == (outer = f1, inner = f2)
#     @test Functors.functor(f1 ∘ f2)[2]((outer = f1, inner = f2)) == f1 ∘ f2
#     @test fmap(x -> x + 10, f1 ∘ f2) == Foo(11.1, 12.2) ∘ Bar(13.3)
#   end
# end

# @testset "Nested" begin
#   model = Bar(Foo(1, [1, 2, 3]))

#   model′ = fmap(float, model)

#   @test model.x.y == model′.x.y
#   @test model′.x.y isa Vector{Float64}
# end

# @testset "Exclude" begin
#   f(x::AbstractArray) = x
#   f(x::Char) = 'z'

#   x = ['a', 'b', 'c']
#   @test fmap(f, x)  == ['z', 'z', 'z']
#   @test fmap(f, x; exclude = x -> x isa AbstractArray) == x

#   x = (['a', 'b', 'c'], ['d', 'e', 'f'])
#   @test fmap(f, x)  == (['z', 'z', 'z'], ['z', 'z', 'z'])
#   @test fmap(f, x; exclude = x -> x isa AbstractArray) == x
# end

# @testset "Walk" begin
#   model = Foo((0, Bar([1, 2, 3])), [4, 5])

#   model′ = fmapstructure(identity, model)
#   @test model′ == (; x=(0, (; x=[1, 2, 3])), y=[4, 5])
# end

# @testset "Property list" begin
#   model = Baz(1, 2, 3)
#   model′ = fmap(x -> 2x, model)
  
#   @test (model′.x, model′.y, model′.z) == (1, 4, 3)
# end

# @testset "fcollect" begin
#   m1 = [1, 2, 3]
#   m2 = 1
#   m3 = Foo(m1, m2)
#   m4 = Bar(m3)
#   @test all(fcollect(m4) .=== [m4, m3, m1, m2])
#   @test all(fcollect(m4, exclude = x -> x isa Array) .=== [m4, m3, m2])
#   @test all(fcollect(m4, exclude = x -> x isa Foo) .=== [m4])

#   m1 = [1, 2, 3]
#   m2 = Bar(m1)
#   m0 = NoChildren(:a, :b)
#   m3 = Foo(m2, m0)
#   m4 = Bar(m3)
#   @test all(fcollect(m4) .=== [m4, m3, m2, m1, m0])
# end

# struct FFoo
#   x
#   y
#   p
# end
# @flexiblefunctor FFoo p

# struct FBar
#   x
#   p
# end
# @flexiblefunctor FBar p

# struct FBaz
#   x
#   y
#   z
#   p
# end
# @flexiblefunctor FBaz p

# @testset "Flexible Nested" begin
#   model = FBar(FFoo(1, [1, 2, 3], (:y, )), (:x,))

#   model′ = fmap(float, model)

#   @test model.x.y == model′.x.y
#   @test model′.x.y isa Vector{Float64}
# end

# @testset "Flexible Walk" begin
#   model = FFoo((0, FBar([1, 2, 3], (:x,))), [4, 5], (:x, :y))

#   model′ = fmapstructure(identity, model)
#   @test model′ == (; x=(0, (; x=[1, 2, 3])), y=[4, 5])

#   model2 = FFoo((0, FBar([1, 2, 3], (:x,))), [4, 5], (:x,))

#   model2′ = fmapstructure(identity, model2)
#   @test model2′ == (; x=(0, (; x=[1, 2, 3])))
# end

# @testset "Flexible Property list" begin
#   model = FBaz(1, 2, 3, (:x, :z))
#   model′ = fmap(x -> 2x, model)

#   @test (model′.x, model′.y, model′.z) == (2, 2, 6)
# end

# @testset "Flexible fcollect" begin
#   m1 = 1
#   m2 = [1, 2, 3]
#   m3 = FFoo(m1, m2, (:y, ))
#   m4 = FBar(m3, (:x,))
#   @test all(fcollect(m4) .=== [m4, m3, m2])
#   @test all(fcollect(m4, exclude = x -> x isa Array) .=== [m4, m3])
#   @test all(fcollect(m4, exclude = x -> x isa FFoo) .=== [m4])

#   m0 = NoChildren(:a, :b)
#   m1 = [1, 2, 3]
#   m2 = FBar(m1, ())
#   m3 = FFoo(m2, m0, (:x, :y,))
#   m4 = FBar(m3, (:x,))
#   @test all(fcollect(m4) .=== [m4, m3, m2, m0])
# end
