using Base: tail

KeyT = Union{Symbol, AbstractString, Integer}

"""
    KeyPath(keys...)

A type for representing a path of keys to a value in a nested structure.
Can be constructed with a sequence of keys, or by concatenating other `KeyPath`s.
Keys can be of type `Symbol`, `String`, or `Int`.

# Examples

```jldoctest
julia> kp = KeyPath(:b, 3)
KeyPath(:b, 3)

julia> KeyPath(:a, kp, :c, 4)
KeyPath(:a, :b, 3, :c, 4)
```
"""
struct KeyPath{T<:Tuple}
    keys::T    
end

@functor KeyPath
isleaf(::KeyPath, @nospecialize(x)) = isleaf(x)

function KeyPath(keys::Union{KeyT, KeyPath}...)
    ks = (k isa KeyPath ? (k.keys...,) : (k,) for k in keys)
    return KeyPath(((ks...)...,))
end

Base.isempty(kp::KeyPath) = false
Base.isempty(kp::KeyPath{Tuple{}}) = true
Base.getindex(kp::KeyPath, i::Int) = kp.keys[i]
Base.length(kp::KeyPath) = length(kp.keys)
Base.iterate(kp::KeyPath, state=1) = iterate(kp.keys, state)
Base.:(==)(kp1::KeyPath, kp2::KeyPath) = kp1.keys == kp2.keys
Base.tail(kp::KeyPath) = KeyPath(Base.tail(kp.keys))
Base.last(kp::KeyPath) = last(kp.keys)

function Base.show(io::IO, kp::KeyPath)
    compat = get(io, :compact, false)
    if compat
        print(io, keypathstr(kp))          
    else
        print(io, "KeyPath$(kp.keys)")
    end
end

keypathstr(kp::KeyPath) = join(kp.keys, ".")

_getkey(x, k::Integer) = x[k]
_getkey(x, k::Symbol) = getfield(x, k)
_getkey(x::AbstractDict, k::Symbol) = x[k]
_getkey(x, k::AbstractString) = x[k]

_haskey(x, k::Integer) = haskey(x, k)
_haskey(x::Tuple, k::Integer) = 1 <= k <= length(x)
_haskey(x::AbstractArray, k::Integer) = 1 <= k <= length(x) # TODO: extend to generic indexing
_haskey(x, k::Symbol) = k in fieldnames(typeof(x))
_haskey(x::AbstractDict, k::Symbol) = haskey(x, k)
_haskey(x, k::AbstractString) = haskey(x, k)

"""
    getkeypath(x, kp::KeyPath)

Return the value in `x` at the path `kp`.

See also [`haskeypath`](@ref).

# Examples
```jldoctest
julia> x = Dict(:a => 3, :b => Dict(:c => 4, "d" => [5, 6, 7]))
Dict{Symbol, Any} with 2 entries:
  :a => 3
  :b => Dict{Any, Any}(:c=>4, "d"=>[5, 6, 7])

julia> getkeypath(x, KeyPath(:b, "d", 2))
6
```
"""
function getkeypath(x, kp::KeyPath)
    if isempty(kp)
        return x
    else
        return getkeypath(_getkey(x, first(kp)), tail(kp))
    end
end

"""
    haskeypath(x, kp::KeyPath)

Return `true` if `x` has a value at the path `kp`.

See also [`getkeypath`](@ref).

# Examples
```jldoctest
julia> x = Dict(:a => 3, :b => Dict(:c => 4, "d" => [5, 6, 7]))
Dict{Any,Any} with 2 entries:
  :a => 3
  :b => Dict{Any,Any}(:c=>4,"d"=>[5, 6, 7])

julia> haskeypath(x, KeyPath(:a))
true

julia> haskeypath(x, KeyPath(:b, "d", 1))
true

julia> haskeypath(x, KeyPath(:b, "d", 4))
false
"""
function haskeypath(x, kp::KeyPath)
    if isempty(kp)
        return true
    else
        k = first(kp)
        return _haskey(x, k) && haskeypath(_getkey(x, k), tail(kp))
    end
end
