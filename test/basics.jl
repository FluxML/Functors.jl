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


@testset "folding" begin
    ten, add = Literal(10), Ident("add")
    call = Call(add, [ten, ten])

    @testset "converting to POJOs" begin
        expected = (fn = (;name="add"), args = [(;val=10), (;val=10)])
        @test Functors.fold(Functors.backing, call) == expected
    end

    @testset "roundtrip" begin
        @test Functors.fold(Functors.embed, call) == call
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
        
    @testset "pretty printing" begin
        prettyprint(l::Functor{Literal}) = repr(l.val)
        prettyprint(i::Functor{Ident}) = i.name
        prettyprint(c::Functor{Call}) = "$(c.fn)($(join(c.args, ",")))"
        prettyprint(i::Functor{Index}) = "$(i.arg)[$(i.idx)]"
        prettyprint(u::Functor{Unary}) = u.op * u.expr
        prettyprint(b::Functor{Binary}) = b.lhs * b.op * b.rhs
        prettyprint(p::Functor{Paren}) = "[$(p.inner)]"
        prettyprint(e) = e
        
        @test Functors.fold(prettyprint, call) == "add(10,10)"
    end

    @testset "zipped fold" begin
        calldata = (fn = (;name="add"), args = [(;val=5), (;val=5)])

        # div(x) = x
        div(x, _) = x
        div(x::Number, y::Number) = x / y
        expected = Call(Ident("add"), [Literal(2.), Literal(2.)])
        @test Functors.rfmap(div, call, calldata) == expected
        
        # pairnums(x) = x
        pairnums(x, y) = x => y
        expected = (fn = (;name="add" => "add"), args = [(;val=5 => 10), (;val=5 => 10)])
        @test Functors.rfmap(pairnums, calldata, call) == expected
    end

    # based on https://github.com/FluxML/Flux.jl/issues/1284
    @testset "L₂ regularization" begin
        struct Chain{T <: Tuple}
            layers::T
        end

        Chain(layers...) = Chain(layers)
        Functors.project(c::Chain) = Functors.Functor{Chain}(c.layers)

        struct Dense{W,B}
            weight::W
            bias::B
        end
        @functor Dense

        struct Conv{W,B}
            weight::W
            bias::B
        end
        @functor Conv

        struct SkipConnection{L,C}
            layer::L
            connection::C
        end
        @functor SkipConnection
        
        _isbitsarray(::AbstractArray{<:Number}) = true
        _isbitsarray(::AbstractArray{T}) where T = isbitstype(T)
        _isbitsarray(x) = false
        custom_isleaf(x) = Functors.isleaf(x) || _isbitsarray(x)

        L₂(x) = sum(something(Functors.children(x), 0))
        L₂(a::AbstractArray{<:Number}) = length(a)
        L₂(d::Functor{Dense}) = d.weight
        L₂(c::Functor{Conv}) = c.weight

        conv1 = Conv(ones(3, 3, 4, 4), ones(4))
        conv2 = Conv(ones(3, 3, 4, 4), ones(4))
        dense1 = Dense(ones(4, 2), ones(2))
        dense2 = Dense(ones(2, 1), ones(1))

        model = Chain(
            SkipConnection(conv1, conv2),
            x -> dropdims(max(x, dims=2), dims=2),
            dense1,
            dense2
        )
        expected = sum(length, (conv1.weight, conv2.weight, dense1.weight, dense2.weight))
        @test Functors.fold(L₂, model; isleaf=custom_isleaf) == expected
    end
end

@testset "unfolding" begin
    function nested(n)
        go(m) = m == 0 ? Literal(n) : functor(Paren, m - 1)
        Functors.unfold(go, n)
    end
    
    # @test nested(3) == 3 |> Literal |> Paren |> Paren |> Paren
end

@static if VERSION >= v"1.6"
        @testset "ComposedFunction" begin
        struct Foo a; b end
        struct Bar c end
        @functor Foo
        @functor Bar
        
        plus10(x) = x
        plus10(x::Real) = x + 10

        f1 = Foo(1.1, 2.2)
        f2 = Bar(3.3)
        @test Functors.children(Functors.project(f1 ∘ f2)) == (outer = f1, inner = f2)
        @test Functors.embed(Functors.project(f1 ∘ f2)) == f1 ∘ f2
        @test Functors.rfmap(plus10, f1 ∘ f2) == Foo(11.1, 12.2) ∘ Bar(13.3)
    end
end