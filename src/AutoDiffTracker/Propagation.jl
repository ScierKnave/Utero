
TwoTensorOperations = (
    Symbol(+), 
    Symbol(-), 
    Symbol(*), 
    Symbol(/), 
    Symbol(^)
)

SingleTensorOperations = (
    Symbol(map),
    Symbol(prod),
    Symbol(sum),
    Symbol(cos), 
    Symbol(sin)
)

function AddJacobian(Jacobians, source, sink, Jacobian)
    # adds jacobian of sink with respect to source to jacobians
    merge!(Jacobians, IdDict((source, sink) => Jacobian)) 
end


function ForwProp(f, x, w::Set)

    # Overcharge the operators to create a computationnal graph as well as 
    # the intermediate jacobians for backpropagation at a later stage

    global Nodes = deepcopy(w)
    global Edges = IdDict()
    global Jacobians = IdDict()

    for op in TwoTensorOperations
        for t in (Symbol(Integer), Symbol(AbstractFloat), Symbol(Array))

            eval(:(global function ($op)(a::T, b::Tracked) where {T<:($t)}
                Node = GenNode(Nodes)
                J = GetJacobian(($op), a, b)
                AddEdge(Edges, b.Node, Node)
                AddJacobian(Jacobians, b.Node, Node, J)
                return Tracked(($op)(a, b.val), Node)
            end))

            eval(:(global function ($op)(a::Tracked, b::T) where {T<:($t)}
                Node = GenNode(Nodes)
                J = GetJacobian(($op), a, b)
                AddEdge(Edges, a.Node, Node)
                AddJacobian(Jacobians, a.Node, Node, J)
                return Tracked(($op)(a.val, b), Node)
            end))

            eval(:(global function ($op)(a::Tracked, b::Tracked)
                Node = GenNode(Nodes)
                Ja = GetJacobian(($op), a, b.val)
                AddEdge(Edges, a.Node, Node)
                AddJacobian(Jacobians, a.Node, Node, Ja)
                Jb = GetJacobian(($op), a.val, b)
                AddEdge(Edges, b.Node, Node)
                AddJacobian(Jacobians, b.Node, Node, Jb)
                return Tracked(($op)(a.val, b.val), Node)
            end))
        end
    end


    for op in SingleTensorOperations
        eval(
            :(
                global function ($op)(a::Tracked)
                    Node = GenNode(Nodes)
                    J = GetJacobian(($op), a)
                    AddEdge(Edges, a.Node, Node)
                    AddJacobian(Jacobians, a.Node, Node, J)
                    return Tracked(($op)(a.val), Node)
                end
            )
        )

        eval(
            :(
                global function ($op)(a::Tracked, args...)
                    Node = GenNode(Nodes)
                    J = GetJacobian(($op), a, args...)
                    AddEdge(Edges, a.Node, Node)
                    AddJacobian(Jacobians, a.Node, Node, J)
                    return Tracked(($op)(a.val, args...), Node)
                end
            )
        )
    end


    y = Base.invokelatest(f, x)
    return (y, Nodes, Edges, Jacobians)
end



function BackProp(y, Nodes, Edges, Jacobians, w)::IdDict
    TopoSortNodes = KahnTopoSort(Nodes, Edges)
    ChainedJacobians = IdDict{Any,Any}(y.Node => 1.0)
    for j in values(Jacobians) println(size(j)) end
    for source in reverse(TopoSortNodes[1:end-1])
        CJ = false
        sinks = get(Edges, source, false)
        for sink in sinks
           
            J = ( get(ChainedJacobians, sink, false) 
                *
                get(Jacobians, (source, sink), false) )
                
            if (CJ == false) CJ = J
            else CJ += J end
        end
        merge!(ChainedJacobians, IdDict(source => CJ))
    end
    Gradients = IdDict(
        [source => get(
            ChainedJacobians, source, false) 
            for source in keys(ChainedJacobians) if source in w])
    return Gradients
end


function GetGradient(f, x, w)::IdDict
    y, Nodes, Edges, Jacobians = ForwProp(f, x, w)
    return BackProp(y, Nodes, Edges, Jacobians, w)
end


