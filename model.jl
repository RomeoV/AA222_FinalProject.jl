include("src/data_wranglage.jl")
function setup_model(optimizer)
  m = Model(optimizer)
  # set_attribute(m, "time_limit", 30)
  # set_attribute(m, "LogFile", "/tmp/foo.log")
  # set_attribute(m, "timeout", 60)


  # vars, data = read_input("data/small.csv")
  vars, data = read_input("data/medium.csv")
  # vars, data = read_input("data/large.csv")
  data = data' .|> Int
  N = length(vars)
  target_idx = N

  S = 1/size(data, 1) * data'*data

  ϵ = 1e-4
  x_hi, x_lo = 10., -10.

  @variable(m,   1  <= o[i=1:N]        <= 2*N, Int)  # maybe don't make integer
  @variable(m, x_lo <= x[i=1:N, j=1:N] <= x_hi)
  @variable(m,   0. <= ξ[i=1:N, j=1:N] <= x_hi)

  @constraint(m, sum(x[N, :]) == 0)  # target node no out edges
  @constraint(m, [i=1:(N-1)], sum(x[i, :]) >= ϵ)  # non-target-node some out edges
  @constraint(m, [i=1:N], sum(x[i, i]) == 0.)  # no self-connections
  @constraint(m, [i=1:N, j=1:N],  x[i, j] <= ξ[i, j])  # L1-regularization
  @constraint(m, [i=1:N, j=1:N], -ξ[i, j] <= x[i, j])  # L1-regularization


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
                 # reformulation=:hull,
                 reformulation=:big_m,
                 M=100.,
                 name=Symbol("y_$(i)_$(j)")
    )
    choose!(m, 1, m[Symbol("y_$(i)_$(j)")]...;
            mode = :exactly, name = "XOR") #XOR constraint
  end

  λ = 0.1
  @objective(m, Min, 1//2*tr((I - x) * (I - x)' * S) + λ*sum(ξ))
  return m
end
