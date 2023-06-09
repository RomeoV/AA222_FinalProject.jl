using CausalityTools
includet("src/data_wranglage.jl")

# vars, data = read_input("data/small.csv")
# vars, data = read_input("data/medium.csv")
vars, data = read_input("data/small.csv")
data = data' .|> Int


xs = eachcol(data)
m = contingency_matrix([c for c in eachcol(data)]...);

# utest = SurrogateTest(MIShannon(), KSG2(k = 3, w = 1); nshuffles = 150)
utest = SurrogateTest(MIShannon(), Contingency(); nshuffles = 150)
ctest = SurrogateTest(CMIShannon(), Contingency(); nshuffles = 150)
# utest = CorrTest()
# ctest = CorrTest()
# independence(SurrogateTest(CMIShannon(), Contingency()), data[:, 1], data[:, 2],

# Infer graph
# alg = OCE(; utest, ctest, α = 0.05, τmax = 1)
alg = PC(utest, ctest)
# alg = OCE(;utest, ctest)
parents = infer_graph(alg, collect(eachcol(data)))
# parents = infer_graph(alg, m)

using Graphs
g = SimpleDiGraph(parents)
collect(edges(g))

using GLMakie, GraphMakie
# g = wheel_graph(10)
f, ax, p = graphplot(g, 
                     # edge_width=[3 for i in 1:ne(g)],
                     nlabels=String.(getfield.(vars, :sym)),
                     # elabels=["$(round(x_[e.src, e.dst], digits=2))" for e in edges(g)],
                     node_size=[10 for i in 1:nv(g)]
                    )

deregister_interaction!(ax, :rectanglezoom)
register_interaction!(ax, :nhover, NodeHoverHighlight(p))
register_interaction!(ax, :ehover, EdgeHoverHighlight(p))
register_interaction!(ax, :ndrag, NodeDrag(p))
register_interaction!(ax, :edrag, EdgeDrag(p))
