using Revise
using LinearAlgebra
using JuMP, DisjunctiveProgramming

using Juniper, Ipopt, HiGHS
ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
highs = optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)
optimizer = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>ipopt)

includet("src/data_wranglage.jl")

# vars, data = read_input("data/small.csv")
vars, data = read_input("data/medium.csv")
data = data' .|> Int

S = 1/size(data, 1) * data'*data

ϵ = 1e-4

m = Model(    optimizer_with_attributes(
        Juniper.Optimizer,
        "nl_solver" => ipopt,
        "mip_solver" => highs,
    ),)
@variable(m, 1  <= o[i=1:length(vars)]                   <=length(vars), Int)
@variable(m, 0. <= x[i=1:length(vars), j=1:length(vars)] <= 1.)


for i in 1:length(vars), j in 1:length(vars)
  add_disjunction!(m,
               @constraints(m, begin
                              x[i, j] >= ϵ
                              x[j, i] == 0
                              o[i]+1 <= o[j]
                          end),
               @constraints(m, begin
                              x[i, j] == 0
                              x[j, i] >= ϵ
                              o[i] >= o[j]+1
                          end),
               @constraints(m, begin
                              x[i, j] == 0
                              x[j, i] == 0
                          end),
               reformulation=:hull,
               # name=Symbol("y$i$j")
  )
end

@objective(m, Min, 1//2*tr((I - x) * (I - x)' * S))

optimize!(m)

x_ = let x_ = value.(x)
  x_[x_.<ϵ] .= 0
  x_
end

using Graphs, GraphPlot
using Cairo, Compose
using Colors

begin
  g = DiGraph(x_)
  plt = gplot(g, nodelabel=getfield.(vars, :sym), nodelabelc=colorant"red")
  draw(PNG("karate.png", 16cm, 16cm), plt)
end

# draw(SVG("karate.svg", 16cm, 16cm), plt)
