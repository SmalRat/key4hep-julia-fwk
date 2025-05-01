using JSON

machine_name::String = "./machine-4"
results_filename_1::String = "results-machine-4-1.json"
results_filename_2::String = "results-machine-4-3.json"

file1 = joinpath(machine_name, results_filename_1)
file2 = joinpath(machine_name, results_filename_2)
results = joinpath(machine_name, "merged.json")

data1 = JSON.parsefile(file1)
data2 = JSON.parsefile(file2)

merged = vcat(data1, data2)
open(results, "w") do io
    JSON.print(io, merged)
end
