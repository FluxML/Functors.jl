using Functors, Test

struct Foo
  x
  y
end

@functor Foo

struct Bar
  x
end

@functor Bar

model = Bar(Foo(1, [1, 2, 3]))

model′ = fmap(float, model)

@test model.x.y == model′.x.y
@test model′.x.y isa Vector{Float64}
