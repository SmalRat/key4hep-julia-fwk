using BenchmarkTools

const DB_DIR = "benchmark_results"

struct TrialEntry
    warmup_results::Dict
    versions::Dict
    benchmarktools_parameters::Dict
    results::Dict
    metadata::Dict
    experiment_parameters::Dict
end


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

dict_to_trial_entry(d::Dict) = TrialEntry(d["warmup_results"], d["versions"], d["benchmarktools_parameters"], d["results"], d["metadata"], d["experiment_parameters"])
dicts_to_trial_entries(dicts::Vector{Dict}) = map(dict_to_trial_entry, dicts)
# db_file_to_trial_entries(filename::AbstractString) = dicts_to_trial_entries(load_db_file(filename))

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
    merge!(trial_dict, parameters)
    trial_dict
end


function filter_by_version(data::Vector{Dict}, key::String, value)
    filter(entry -> get(entry["versions"], key, nothing) == value, data)
end

function filter_by_experiment_parameters(data::Vector{Dict}, key::String, value)
    filter(entry -> get(entry["experiment_parameters"], key, nothing) == value, data)
end

function filter_by_benchmarktools_parameters(data::Vector{Dict}, key::String, value)
    filter(entry -> get(entry["benchmarktools_parameters"], key, nothing) == value, data)
end


function trial_append_to_db(filename::AbstractString, t::BenchmarkTools.Trial, parameters::Dict)
    filename = joinpath(DB_DIR, filename)

    data = load_db_file(filename)

    new_entry = t |> trial_to_dict |> (x -> trial_add_worker_parameters(x, parameters))

    push!(data, new_entry)

    open(filename, "w") do io
        JSON.print(io, data, 2)
    end
end
