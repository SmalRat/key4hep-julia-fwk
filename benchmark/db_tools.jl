const DB_DIR = "benchmark_results"


function load_db_file(filename::AbstractString)::Vector{Dict}
    endswith(filename, ".json") || badext(filename)
    mkpath(DB_DIR)

    existing_data = if isfile(filename)
        try
            open(filename, "r") do io
                JSON.parse(io)
            end
        catch
            []
        end
    else
        []
    end
    return convert(Vector{Dict}, existing_data)
end


function trial_format_results(trial_json)
    version_info = trial_json[1]

    trial_data = trial_json[2][1][2]
    trial_params = trial_data["params"][2]

    results = Dict("allocations" => trial_data["allocs"],
               "memory_usage" => trial_data["memory"],
               "gc_times" => trial_data["gctimes"],
               "execution_times" => trial_data["times"])

    return Dict(
        "versions" => version_info,
        "results" => results,
        "benchmarktools_parameters" => trial_params
    )
end


function trial_to_dict(t::BenchmarkTools.Trial)
    # Generate new dict from BenchmarkTools.Trial object
    buffer = IOBuffer()
    BenchmarkTools.save(buffer, t)
    return trial_format_results(JSON.parse(String(take!(buffer))))
end


function trial_add_worker_parameters(trial_dict::Dict, parameters::Dict)
    parameters_ = copy(parameters)
    trial_dict["versions"]["Benchmark_version"] = parameters_["metadata"]["benchmark_version"]
    pop!(parameters_, "metadata")
    trial_dict["parameters"] = parameters_
    trial_dict
end


function filter_by_version(data::Vector{Dict}, key::String, value)
    filter(entry -> get(entry["versions"], key, nothing) == value, data)
end

function filter_by_parameters(data::Vector{Dict}, key::String, value)
    filter(entry -> get(entry["parameters"], key, nothing) == value, data)
end

function filter_by_benchmarktools_parameters(data::Vector{Dict}, key::String, value)
    filter(entry -> get(entry["benchmarktools_parameters"], key, nothing) == value, data)
end


function append_save(filename::AbstractString, t::BenchmarkTools.Trial, parameters::Dict)
    filename = joinpath(DB_DIR, filename)

    data = load_db_file(filename)

    new_entry = t |> trial_to_dict |> (x -> trial_add_worker_parameters(x, parameters))

    push!(data, new_entry)

    open(filename, "w") do io
        JSON.print(io, data, 2)
    end
end
