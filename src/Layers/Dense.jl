
@doc """
Dense layers consist of a linear mapping followed by a non linear element-wise activation function.
"""
struct Dense <: Mutator
    w::Matrix
    b::Vector
    f::Function
end

function Dense(InDim::Int, OutDim::Int, f::Function)
    w = rand(Float16, (OutDim, InDim))
    b = rand(Float16, (OutDim))
    return Dense(w, b, f)
end

function (d::Dense)(v::AbstractArray{<:Real,1})
    return d.f(+(*(d.w, v), d.b))
end

function (d::Dense)(x::Array{<:Real,2})
    y = Array{Number,2}(undef, size(x)[1], size(d.w)[1])
    for (RowInd, v) in enumerate(eachrow(x))
        y[RowInd, :] = d(v)
    end
    return y
end
