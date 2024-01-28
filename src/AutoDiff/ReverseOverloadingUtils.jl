mutable struct ⬅Context
    Params
    Tape
    Jacobians::Dict
    Counter
    function ⬅Context()
        return new([], [], Dict(), [0])
    end
end

mutable struct ⬅Tracker{T}
    val::T
    id::Int64 
    Chainers
    Childs
    function ⬅Tracker(val) 
        global Counter[1] += 1
        id = Counter[1]
        return new{typeof(val)}(val, id, [], [])
    end

    function ⬅Tracker(ctx::⬅Context, val) 
        ctx.Counter[1] += 1
        return new{typeof(val)}(val, ctx.Counter[1], [], [])
    end

    ⬅Tracker(x::⬅Tracker)  = x
    ⬅Tracker(ctx, x::⬅Tracker)  = x
end

convert(::Type{⬅Tracker}, x::Real) = ⬅Tracker(x)
convert(::Type{⬅Tracker}, x::Int) = ⬅Tracker(x)
promote_rule(::Type{⬅Tracker}, ::Type{<:Number}) = ⬅Tracker


function Untrack(X::⬅Tracker...)
    return [x.val for x in X]
end
    
""" 
The following set of Macro is to help quickly overload functions
with simple arguments (Unary) or (Binary)
"""

macro ⬅UnaryScalarFunctionOL(func)
    return :(
        function $func(x::⬅Tracker{T}) where T<:Number
            (z, Chainer) = ⬅Dual($func, x.val)
            z = ⬅Tracker(z)
            push!(x.Chainers, ∇ -> Chainer(∇))
            push!(x.Childs, z.id)
            push!(Tape, x)
            return z
        end
    )
end


macro ⬅BinaryScalarFunctionOL(func)
    return :(
            function $func(x::⬅Tracker{T}, y::⬅Tracker{G}) where {T<:Number, G<:Number}
                z, Chainer = ⬅Dual($func, x.val, y.val)
                z = ⬅Tracker(z)
                for (s, i) in [(x, 1), (y, 2)]
                    push!(s.Chainers, ∇ -> Chainer(∇)[i])
                    push!(s.Childs, z.id)
                    push!(Tape, s)
                end
                return z
            end,

            function $func(x::⬅Tracker{T}, y::Number) where T<:Number
                z, Chainer = ⬅Dual($func, x.val, y)
                z = ⬅Tracker(z)
                push!(x.Chainers, ∇ -> Chainer(∇)[1])
                push!(x.Childs, z.id)
                push!(Tape, x)
                return z
            end,

            function $func(x::Number, y::⬅Tracker{T}) where T<:Number
                z, Chainer = ⬅Dual($func, x, y.val)
                z = ⬅Tracker(z)
                push!(y.Chainers, ∇ -> Chainer(∇)[2])
                push!(y.Childs, z.id)
                push!(Tape, y)
                return z
            end
    )
end


macro ⬅UnaryFunctionOL(func)
    return :(
        function $func(X::⬅Tracker{T}) where T
            (z, Chainer) = ⬅Dual($func, X.val)
            z = ⬅Tracker(z)
            push!(X.Chainers, ∇ -> Chainer(∇))
            push!(X.Childs, z.id)
            push!(Tape, X)
            return z
        end
    )
end


macro ⬅BinaryFunctionOL(func)
    return :(
        function $func(x::⬅Tracker, y::⬅Tracker) 
            z, Chainer = ⬅Dual($func, x.val, y.val)
            z = ⬅Tracker(z)
            for (s, i) in [(x, 1), (y, 2)]
                push!(s.Chainers, ∇ -> Chainer(∇)[i])
                push!(s.Childs, z.id)
                push!(Tape, s)
            end
            return z
        end,

        function $func(x::⬅Tracker, y::G) where {T, G<:Union{AbstractArray, Number}}
            z, Chainer = ⬅Dual($func, x.val, y)
            z = ⬅Tracker(z)
            push!(x.Chainers, ∇ -> Chainer(∇)[1])
            push!(x.Childs, z.id)
            push!(Tape, x)
            return z
        end,

        function $func(x::G, y::⬅Tracker) where {T, G<:Union{AbstractArray, Number}}
            z, Chainer = ⬅Dual($func, x, y.val)
            z = ⬅Tracker(z)
            push!(y.Chainers, ∇ -> Chainer(∇)[2])
            push!(y.Childs, z.id)
            push!(Tape, y)
            return z
        end
    )
end

