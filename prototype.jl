using Revise
using LinearAlgebra
using JuMP, DisjunctiveProgramming

using Juniper, Ipopt, HiGHS, GLPK, Pavito, Gurobi
ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
highs = optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)

# optimizer = optimizer_with_attributes(
#         Juniper.Optimizer,
#         "nl_solver" => ipopt,
#         "mip_solver" => highs,
#     )

# optimizer =  optimizer_with_attributes(
#         Pavito.Optimizer,
#         "mip_solver" => highs,
#         "cont_solver" => optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
#         "rel_gap" => 1e-4,
#     )

optimizer = Gurobi.Optimizer

includet("src/data_wranglage.jl")

vars, data = read_input("data/small.csv")
# vars, data = read_input("data/medium.csv")
data = data' .|> Int

S = 1/size(data, 1) * data'*data

ϵ = 1e-4

m = Model(optimizer)
@variable(m, 1  <= o[i=1:length(vars)]                   <=length(vars), Int)
@variable(m, 0. <= x[i=1:length(vars), j=1:length(vars)] <= 1.)

N = length(vars)
target_idx = N
@constraint(m, sum(x[N, :]) == 0)
@constraint(m, [i=1:(N-1)], sum(x[i, :]) >= 1.)
@constraint(m, [i=1:N], sum(x[i, i]) == 0.)


for i in 1:N, j in (i+1):N
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
               # M=100.,
               name=Symbol("y_$(i)_$(j)")
  )
  choose!(m, 1, m[Symbol("y_$(i)_$(j)")]...; mode = :exactly, name = "XOR") #XOR constraint
end

λ = 0.1
@objective(m, Min, 1//2*tr((I - x) * (I - x)' * S) + λ*sum(x))

optimize!(m)

## PROCESS SOLUTION

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
