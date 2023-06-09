# data_wranglage.jl
import CSV: read
import DataFrames: DataFrame

Domain_t = Int  # for variable assignments
struct Variable
  sym :: Symbol
  domain :: Domain_t
end
Variable((sym, domain)::Tuple) = Variable(sym, domain)

function build_variables(data::DataFrame)
  syms = names(data) .|> Symbol
  domains = maximum.(eachcol(data))
  return Variable.(zip(syms, domains))
end

" Read csv file
Data is in (n x num_obs) to exploit locality in row-major ordering. "
function read_input(filepath::String = "data/small.csv")
  data = read(filepath , DataFrame)
  vars = build_variables(data)
  # permutedims is non-lazy transpose
  data_mat = Matrix{Domain_t}(data)
  return vars, data_mat
end
