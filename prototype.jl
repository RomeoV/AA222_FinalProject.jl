using LinearAlgebra
using JuMP, DisjunctiveProgramming
include("model.jl")

using Juniper, Ipopt, HiGHS, GLPK, Pavito, Gurobi, Pajarito, Hypatia
ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
highs = optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)
# highs = optimizer_with_attributes(
#               HiGHS.Optimizer,
#               MOI.Silent() => true,
#               "mip_feasibility_tolerance" => 1e-8,
#               "mip_rel_gap" => 1e-6,
#           )
hypatia = optimizer_with_attributes(Hypatia.Optimizer, MOI.Silent() => true)

gurobi = Gurobi.Optimizer


# optimizer = optimizer_with_attributes(
#         Juniper.Optimizer,
#         "nl_solver" => ipopt,
#         "mip_solver" => highs,
#         "rel_gap" => 1e-4,
#     )

optimizer =  optimizer_with_attributes(
        Pavito.Optimizer,
        "mip_solver" => highs,
        "cont_solver" => ipopt,
        "rel_gap" => 1e-4,
    )

optimizer = optimizer_with_attributes(
          Pajarito.Optimizer,
          "oa_solver" => highs,
          "conic_solver" => hypatia,
          # "rel_gap" => 1e-4,
      )

optimizer = optimizer_with_attributes(
                Gurobi.Optimizer,
                "timelimit" => 30,
                "LogFile" => "/tmp/foo.log",
      )

m = setup_model(optimizer)
optimize!(m)
## PROCESS SOLUTION


ϵ = 1e-4
x_ = let x_ = value.(m[:x])
  x_[x_.<ϵ] .= 0
  x_
end

using Graphs, GraphPlot
using Cairo, Compose
using Colors

g = DiGraph(x_)
@assert !is_cyclic(g) && is_connected(g)
plt = gplot(g, nodelabel=getfield.(vars, :sym),
               nodelabelc=colorant"red",
               edgelabel=[round(x_[e.src, e.dst], digits=2) for e in edges(g)],
                edgelabelc=colorant"blue")
draw(PNG("karate.png", 16cm, 16cm), plt)
draw(PDF("small.pdf", 12cm, 12cm), plt)

# draw(SVG("karate.svg", 16cm, 16cm), plt)

using GLMakie, GraphMakie
# g = wheel_graph(10)
f, ax, p = graphplot(g, 
                     # edge_width=[3 for i in 1:ne(g)],
                     nlabels=String.(getfield.(vars, :sym)),
                     elabels=["$(round(x_[e.src, e.dst], digits=2))" for e in edges(g)],
                     node_size=[10 for i in 1:nv(g)]
                    )

deregister_interaction!(ax, :rectanglezoom)
register_interaction!(ax, :nhover, NodeHoverHighlight(p))
register_interaction!(ax, :ehover, EdgeHoverHighlight(p))
register_interaction!(ax, :ndrag, NodeDrag(p))
register_interaction!(ax, :edrag, EdgeDrag(p))
