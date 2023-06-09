using Plots, StatsPlots; unicodeplots()
using DataFrames
include("parse_gurobi.jl")

files = readdir() |> filter(s->split(s, '.')[end]=="log")

colnames = ["time", "gap", "penalty", "problem", "max_parents"]
df = DataFrame([Int[], Float32[], Symbol[], String[], Int[]], colnames)
dfs = []
for f in files
  @info f
  problem = match(r"(small|medium|large)", f).captures[1]
  !(problem ∈ ["small", "medium"]) && continue

  times, gaps = parse_gurobi_file(joinpath("results", f))
  penalty = match(r"penalty_type=(L(1|2|inf))", f).captures[1] |> Symbol
  timeout = match(r"timeout=([0-9]+)", f).captures[1] |> s->parse(Int, s)
  max_parents = match(r"max_parents=([0-9]+)", f).captures[1] |> s->parse(Int, s)
  N = length(times)

  push!(dfs, DataFrame([times, gaps, 
                        fill(penalty, N), 
                        fill(problem, N),
                        fill(max_parents, N)],
                       colnames))

end
df = vcat(dfs...)

get_marker(s) = Plots.supported_markers()[findfirst(==(s), unique(df.penalty))+2]
# @df filter(:problem=>==("small"), df) scatter(:time, :gap; group=(:penalty, :max_parents), markershape=get_marker.(:penalty), alpha=0.5)

map_penalty(penalty::Symbol) = let markers = Plots.supported_markers()
  @match penalty begin
    :L1 => markers[3]
    :L2 => markers[4]
    :Linf => markers[6]
  end
end
map_penalty2(penalty::Symbol) = let markers = Plots.supported_markers()
  @match penalty begin
    :L1 => 1
    :L2 => 2
    :Linf => 3
  end
end
map_problem(prob::AbstractString) = @match prob begin
  "small" => 1
  "medium" => 2
  "large" => 3
end
map_max_parents(mp::Int) = @match mp begin
  2 => :solid
  4 => :dash
  8 => :dashdot
end

plt = plot(; legend=true, legendposition=:topright,
           # yaxis=:log2, 
           ylabel="optimality gap [%]", ylims=(0.15, 0.25),
           xlabel="time [s]")
dfg = groupby(filter(:problem=>==("medium"), df), [:penalty, :problem, :max_parents])
for k in keys(dfg)
  df_ = dfg[k]
  plot!(plt, df_.time, df_.gap;
        linestyle=map_max_parents(k.max_parents), color=map_penalty2(k.penalty),
        label="$(k.penalty) -- $(k.max_parents)")
  # scatter!(plt, df_.time, df_.gap; marker=map_penalty(k.penalty), color=map_problem(k.problem))
end
plt
