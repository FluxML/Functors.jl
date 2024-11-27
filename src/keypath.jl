using Base: tail

KeyT = Union{Symbol, AbstractString, Integer, CartesianIndex}

"""
    KeyPath(keys...)

A type for representing a path of keys to a value in a nested structure.
Can be constructed with a sequence of keys, or by concatenating other `KeyPath`s.
Keys can be of type `Symbol`, `String`, `Int`, or `CartesianIndex`.

For custom types, access through symbol keys is assumed to be done with `getproperty`.
For consistency, the method `Base.propertynames` is used to get the viable property names.

For string, integer, and cartesian index keys, the access is done with `getindex` instead.

See also [`getkeypath`](@ref), [`haskeypath`](@ref).

# Examples

```jldoctest
julia> kp = KeyPath(:b, 3)
KeyPath(:b, 3)

julia> KeyPath(:a, kp, :c, 4) # construct mixing keys and keypaths
KeyPath(:a, :b, 3, :c, 4)

julia> struct T
           a
           b
       end

julia> function Base.getproperty(x::T, k::Symbol)
            if k in fieldnames(T)
                return getfield(x, k)
            elseif k === :ab
                return "ab"
            else        
                error()
            end
        end;

julia> Base.propertynames(::T) = (:a, :b, :ab);

julia> x = T(3, Dict(:c => 4, :d => 5));

julia> getkeypath(x, KeyPath(:ab)) # equivalent to x.ab
"ab"

julia> getkeypath(x, KeyPath(:b, :c)) # equivalent to (x.b)[:c]
4
```
"""
struct KeyPath{T<:Tuple}
    keys::T    
end

isleaf(::KeyPath, @nospecialize(x)) = isleaf(x)

function KeyPath(keys::Union{KeyT, KeyPath}...)
    ks = (k isa KeyPath ? (k.keys...,) : (k,) for k in keys)
    return KeyPath(((ks...)...,))
end

Base.isempty(kp::KeyPath) = false
Base.isempty(kp::KeyPath{Tuple{}}) = true
Base.getindex(kp::KeyPath, i::Integer) = kp.keys[i]
Base.getindex(kp::KeyPath, r::AbstractVector) = KeyPath(kp.keys[r])
Base.last(kp::KeyPath) = last(kp.keys)
Base.lastindex(kp::KeyPath) = lastindex(kp.keys)
Base.length(kp::KeyPath) = length(kp.keys)
Base.iterate(kp::KeyPath, state=1) = iterate(kp.keys, state)
Base.tail(kp::KeyPath) = KeyPath(Base.tail(kp.keys))
Base.:(==)(kp1::KeyPath, kp2::KeyPath) = kp1.keys == kp2.keys

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
_getkey(x::AbstractArray, k::CartesianIndex) = x[k]
_getkey(x, k::Symbol) = getproperty(x, k)
_getkey(x::AbstractDict, k::Symbol) = x[k]
_getkey(x, k::AbstractString) = x[k]

_setkey!(x, k::Integer, v) = (x[k] = v)
_setkey!(x::AbstractArray, k::CartesianIndex, v) = (x[k] = v)
_setkey!(x, k::Symbol, v) = setproperty!(x, k, v)
_setkey!(x::AbstractDict, k::Symbol, v) = (x[k] = v)
_setkey!(x, k::AbstractString, v) = (x[k] = v)

_haskey(x, k::Integer) = haskey(x, k)
_haskey(x::Tuple, k::Integer) = 1 <= k <= length(x)
_haskey(x::AbstractArray, k::Integer) = 1 <= k <= length(x) # TODO: extend to generic indexing
_haskey(x::AbstractArray, k::CartesianIndex) = checkbounds(Bool, x, k)
_haskey(x, k::Symbol) = k in propertynames(x)
_haskey(x::AbstractDict, k::Symbol) = haskey(x, k)
_haskey(x, k::AbstractString) = haskey(x, k)


"""
    getkeypath(x, kp::KeyPath)

Return the value in `x` at the path `kp`.

See also [`KeyPath`](@ref), [`haskeypath`](@ref), and [`setkeypath!`](@ref).

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

See also [`KeyPath`](@ref), [`getkeypath`](@ref), and [`setkeypath!`](@ref).

# Examples
```jldoctest
julia> x = Dict(:a => 3, :b => Dict(:c => 4, "d" => [5, 6, 7]))
Dict{Symbol, Any} with 2 entries:
  :a => 3
  :b => Dict{Any, Any}(:c=>4, "d"=>[5, 6, 7])

julia> haskeypath(x, KeyPath(:a))
true

julia> haskeypath(x, KeyPath(:b, "d", 1))
true

julia> haskeypath(x, KeyPath(:b, "d", 4))
false
```
"""
function haskeypath(x, kp::KeyPath)
    if isempty(kp)
        return true
    else
        k = first(kp)
        return _haskey(x, k) && haskeypath(_getkey(x, k), tail(kp))
    end
end

"""
    setkeypath!(x, kp::KeyPath, v)

Set the value in `x` at the path `kp` to `v`.

See also [`KeyPath`](@ref), [`getkeypath`](@ref), and [`haskeypath`](@ref).
"""
function setkeypath!(x, kp::KeyPath, v)
    if isempty(kp)
        error("Empty keypath not allowed.")
    end
    y = getkeypath(x, kp[1:end-1])
    k = kp[end]
    return _setkey!(y, k, v)
end
