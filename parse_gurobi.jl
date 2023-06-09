function parse_gurobi_file(filename)
  io = open(filename, "r")
  readuntil(io, " Expl Unexpl |  Obj  Depth IntInf | Incumbent    BestBd   Gap | It/Node Time")
  readline(io); readline(io)
  lines = split(readuntil(io, "\n\n"), "\n")
  close(io)

  timings = Int[];
  gaps = Float32[];
  map(lines) do l
    try
      gap, time = split(l)[[end-2, end]]
      time = parse(Int, time[1:end-1])
      gap = parse(Float32, gap[1:end-1])/100
      push!(timings, time)
      push!(gaps, gap)
    catch
    end
  end;
  return timings, gaps
end

if abspath(PROGRAM_FILE) == @__FILE__
  # filename = "results/trace_gurobi_small.log"
  filename = "results/trace_gurobi_medium.log"
  ts, gs = parse_gurobi_file(filename)
  plot(ts, gs)
end


function parse_parito(filename)
  io = open(filename, "r")
  readuntil(io, " Iter. | Best feasible  | Best bound     | Rel. gap    | Time (s)   \n")
end
