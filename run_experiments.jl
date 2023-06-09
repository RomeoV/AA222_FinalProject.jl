using JuMP, DisjunctiveProgramming
using Juniper, Ipopt, HiGHS, GLPK, Pavito, Gurobi, Pajarito, Hypatia
using Match
using TeeStreams

include("src/data_wranglage.jl")
include("model.jl")

files = ["small.csv",
         "medium.csv",
         "large.csv"]
solvers = [:gurobi,
           # :juniper,
           :pavito,
           # :pajarito
          ]


function run(; solver=:gurobi, infile="small.csv", timeout=60, max_parents=nothing, penalty_type=:L1)
  tracefile = "trace_$(solver)_$(replace(infile, ".csv"=>""))_timeout=$(timeout)_max_parents=$(max_parents)_penalty_type=$(penalty_type).log"

  opt = make_optimizer(solver, timeout)

  vars, data = read_input("data/$infile")
  m = setup_model(data; max_parents)
  set_optimizer(m, opt; add_bridges=false)
  # set_optimizer(m, opt)

  # open(joinpath("results", tracefile), "w") do fd
  #   teestream = TeeStream(fd, stdout)
    # redirect_stdout(fd) do
      optimize!(m)
    # end
  # end
end

ipopt = optimizer_with_attributes(Ipopt.Optimizer, MOI.Silent() => true)
highs = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
hypatia = optimizer_with_attributes(Hypatia.Optimizer, MOI.Silent() => true)


make_optimizer(solver, timelimit=60) = @match solver begin
    :gurobi => optimizer_with_attributes(
                    Gurobi.Optimizer,
                    "time_limit"=>timelimit
    )
    :juniper => optimizer_with_attributes(
                    Juniper.Optimizer,
                    "nl_solver" => ipopt,
                    "mip_solver" => highs,
                )
    :pavito => optimizer_with_attributes(
          Pavito.Optimizer,
          "mip_solver" => highs,
          "cont_solver" => ipopt,
          "rel_gap" => 1e-4,
          "timeout" => timelimit,
      )
    :pajarito => optimizer_with_attributes(
            Pajarito.Optimizer,
            "oa_solver" => highs,
            "conic_solver" => hypatia,
        )
end
