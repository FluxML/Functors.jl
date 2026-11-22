###
### Type-erased access to children, compiled once for all types
###

"""
    ErasedChildren

The children of a node, as returned by [`erased_children`](@ref Functors.erased_children).
`keys(c)` and `values(c)` are `Vector{Any}`s, holding the keys and values of
[`children`](@ref Functors.children)`(x)` in iteration order.
"""
struct ErasedChildren
  keys::Vector{Any}
  vals::Vector{Any}
end

Base.keys(c::ErasedChildren) = c.keys
Base.values(c::ErasedChildren) = c.vals
Base.length(c::ErasedChildren) = length(c.vals)

"""
    erased_children(x)

Return the [`children`](@ref Functors.children) of `x` as an
[`ErasedChildren`](@ref Functors.ErasedChildren), whose `keys` and `values` are `Vector{Any}`s,
or `nothing` when `children(x) === Functors.NoChildren()`.

Keys are field names for structs and `NamedTuple`s, indices for `Tuple`s and arrays,
as in a [`KeyPath`](@ref), and the keys of an `AbstractDict`.

This is for code that reads a structure without rebuilding it, such as printing a model or
counting its arrays. Calling `children(x)` compiles `functor` for each new type of `x`,
while `erased_children` is compiled once. For types that use the default `functor`, and
for `Tuple`s, `NamedTuple`s, leaves defined by Functors and arrays which are not leaves,
it reads the children directly. For types with their own `functor` or `children` methods,
it calls `children(x)` and converts the result.

See also [`erased_isleaf`](@ref Functors.erased_isleaf).

# Examples

```jldoctest
julia> struct Foo; a; b; end

julia> c = Functors.erased_children(Foo(1, [2, 3]));

julia> keys(c), values(c)
(Any[:a, :b], Any[1, [2, 3]])

julia> Functors.erased_children([4.0, 5.0]) === nothing  # an array of numbers is a leaf
true
```
"""
Base.@nospecializeinfer function erased_children(@nospecialize(x))
  kind = _erased_kinds(typeof(x)).children
  if kind == _FIELDS
    T = typeof(x)
    n = fieldcount(T)
    n == 0 && return nothing
    ks = Vector{Any}(undef, n)
    vs = Vector{Any}(undef, n)
    for i in 1:n
      ks[i] = fieldname(T, i)
      vs[i] = getfield(x, i)
    end
    return ErasedChildren(ks, vs)
  elseif kind == _LEAF
    return nothing
  elseif kind == _ITSELF
    return _erase(x)
  else
    return _erase(children(x))
  end
end

"""
    erased_isleaf(x)

The same as [`isleaf`](@ref Functors.isleaf)`(x)`, but compiled once for all types,
like [`erased_children`](@ref Functors.erased_children).
"""
Base.@nospecializeinfer function erased_isleaf(@nospecialize(x))::Bool
  k = _erased_kinds(typeof(x))
  k.isleaf || return isleaf(x)
  if k.children == _FIELDS
    return fieldcount(typeof(x)) == 0
  elseif k.children == _LEAF
    return true
  elseif k.children == _ITSELF
    return x === NoChildren()
  else
    return children(x) === NoChildren()
  end
end

Base.@nospecializeinfer function _erase(@nospecialize(ch))
  ch === NoChildren() && return nothing
  if ch isa Union{Tuple, NamedTuple}
    n = nfields(ch)
    ks = Vector{Any}(undef, n)
    vs = Vector{Any}(undef, n)
    for i in 1:n
      ks[i] = ch isa NamedTuple ? fieldname(typeof(ch), i) : i
      vs[i] = getfield(ch, i)
    end
    return ErasedChildren(ks, vs)
  else  # an AbstractArray, AbstractDict, or anything else with keys and values
    return ErasedChildren(vec(collect(Any, keys(ch))), vec(collect(Any, values(ch))))
  end
end

# How to find the children of `x::T`, depending on which methods of `functor` etc. apply.
# Calling `children(x)` would compile `functor(::Type{T}, ::T)` for each new `T`, so instead
# `which` tells us when Functors' own methods apply, and the result is cached for each `T`.
@enum _ChildrenKind::UInt8 begin
  _FIELDS  # the default `functor`, so the children are the fields of `x`
  _LEAF    # one of Functors' `@leaf` methods
  _ITSELF  # the children are `x` itself: a Tuple, NamedTuple or AbstractArray
  _CALL    # anything else: call `children(x)`
end

struct _ErasedKinds
  children::_ChildrenKind
  isleaf::Bool  # whether `isleaf` is the default method, which calls `children`
end

const _DEFAULT_CHILDREN = which(children, Tuple{Any})
const _DEFAULT_FUNCTOR1 = which(functor, Tuple{Any})
const _DEFAULT_ISLEAF = which(isleaf, Tuple{Any})

const _FUNCTOR_KINDS = let d = IdDict{Any, _ChildrenKind}()
  d[which(functor, Tuple{Any, Any})] = _FIELDS
  for T in (Tuple{Int}, @NamedTuple{a::Int}, Vector{Any})
    d[which(functor, Tuple{Type{T}, T})] = _ITSELF
  end
  # One instance of each `@leaf` in base.jl:
  for x in (Int, 1, [1.0], "s", 's', match(r"s", "s"), r"s", Random.Xoshiro(1))
    d[which(functor, Tuple{Type{typeof(x)}, typeof(x)})] = _LEAF
  end
  d
end

const _ERASED_KINDS = IdDict{Any, _ErasedKinds}()
const _ERASED_KINDS_WORLD = Ref(typemax(UInt))
const _ERASED_KINDS_LOCK = ReentrantLock()

# Forgets everything whenever the world age changes, as new methods may have been defined.
Base.@nospecializeinfer function _erased_kinds(@nospecialize(T::Type))
  world = Base.get_world_counter()
  lock(_ERASED_KINDS_LOCK)
  try
    if _ERASED_KINDS_WORLD[] != world
      empty!(_ERASED_KINDS)
      _ERASED_KINDS_WORLD[] = world
    end
    k = get(_ERASED_KINDS, T, nothing)
    if k === nothing
      k = _ERASED_KINDS[T] = _find_erased_kinds(T)
    end
    return k::_ErasedKinds
  finally
    unlock(_ERASED_KINDS_LOCK)
  end
end

Base.@nospecializeinfer function _find_erased_kinds(@nospecialize(T::Type))
  kind = _CALL
  if _which(children, Tuple{T}) === _DEFAULT_CHILDREN && _which(functor, Tuple{T}) === _DEFAULT_FUNCTOR1
    kind = get(_FUNCTOR_KINDS, _which(functor, Tuple{Type{T}, T}), _CALL)
  end
  return _ErasedKinds(kind, _which(isleaf, Tuple{T}) === _DEFAULT_ISLEAF)
end

# `nothing` when there is no unique method, e.g. an ambiguity. Then `_CALL` reports the error.
Base.@nospecializeinfer function _which(@nospecialize(f), @nospecialize(tt::Type))
  try
    return which(f, tt)
  catch err
    err isa ErrorException || err isa MethodError || rethrow()
    return nothing
  end
end
