using LinearAlgebra
include("src/data_wranglage.jl")
function setup_model(data;
    max_parents::Union{Nothing, Int}=nothing,
    penalty_fct::Float64=0.1,
    penalty_type::Symbol=:L1,
    reformulation=:big_m)
  @assert penalty_type ∈ [:L1, :L2, :Linf]
  λ = penalty_fct # just an alias

  m = Model()

  n_samples, N = size(data)
  target_idx = N

  S = 1/n_samples * data'*data

  ϵ = 1e-4
  x_lo, x_hi = -10., +10.

  ## define vars
  @variable(m,   1  <= o[i=1:N]        <= N, Int)  # maybe don't make integer
  @variable(m, x_lo <= x[i=1:N, j=1:N] <= x_hi)
  if penalty_type == :L1
    @variable(m,   0. <= ξ[i=1:N, j=1:N] <= x_hi)
  elseif penalty_type == :Linf
    @variable(m,   0. <= ξ <= x_hi)
  end

  ## define basic constraints
  @constraint(m, sum(x[N, :]) == 0)  # target node no out edges
  @constraint(m, [i=1:(N-1)], sum(x[i, :]) >= ϵ)  # non-target-node some out edges
  @constraint(m, [i=1:N], sum(x[i, i]) == 0.)  # no self-connections

  if penalty_type == :L1
    @constraint(m, [i=1:N, j=1:N],  x[i, j] <= ξ[i, j])
    @constraint(m, [i=1:N, j=1:N], -ξ[i, j] <= x[i, j])
  elseif penalty_type == :Linf
    @constraint(m, [i=1:N, j=1:N],  x[i, j] <= ξ)
    @constraint(m, [i=1:N, j=1:N], -ξ <= x[i, j])
  end

  ## add DAG disjunctions
  for i in 1:N, j in (i+1):N
    add_disjunction!(m,
                 @constraints(m, begin
                                # x[i, j] >= ϵ
                                x[j, i] == 0
                                o[i]+1 <= o[j]
                            end),
                 @constraints(m, begin
                                x[i, j] == 0
                                # x[j, i] >= ϵ
                                o[i] >= o[j]+1
                            end),
                 @constraints(m, begin
                                x[i, j] == 0
                                x[j, i] == 0
                            end),
                 reformulation=reformulation,
                 M=100.,
                 name=Symbol("y_$(i)_$(j)")
    )
    choose!(m, 1, m[Symbol("y_$(i)_$(j)")]...;
            mode = :exactly, name = "XOR_$(i)_$(j)") #XOR constraint
  end

  # define alias
  @variable(m, Y[i=1:N, j=1:N], Bin)
  @constraint(m, [i=1:N], Y[i, i] == 0)
  @constraint(m, [i=1:N, j=i+1:N], Y[i, j] == m[Symbol("y_$(i)_$(j)")][1])
  @constraint(m, [i=1:N, j=1:i-1], Y[i, j] == m[Symbol("y_$(j)_$(i)")][2])


  ## add max_parents constraints
  if !isnothing(max_parents)
    @constraint(m, [j=1:N],  sum(Y[:, j]) ≤ max_parents)
  end

  ## make sure graph is fully connected
  @constraint(m, [i=2:N], sum(Y[:, i]) + sum(Y[i, :]) ≥ 1)

  @objective(m, Min, 1/2*tr((I - x) * (I - x)' * S) + 
             @match penalty_type begin
               :L1 => λ*sum(ξ)
               :L2 => λ*sum(x.^2)
               :Linf => λ*ξ
             end)
  return m
end
