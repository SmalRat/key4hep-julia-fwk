using BenchmarkTools
using JSON

const DB_DIR = "benchmark_results"

struct TrialEntry
    warmup_results::Dict
    versions::Dict
    benchmarktools_parameters::Dict
    results::Dict
    metadata::Dict
    experiment_parameters::Dict
    machine_info::Dict
end

# Loading entries from file

function load_db_file_to_dicts(filename::AbstractString)::Vector{Dict}
    endswith(filename, ".json") || badext(filename)
    mkpath(DB_DIR)

    existing_data::Vector{Dict} = if isfile(filename)
        try
            open(filename, "r") do io
                res = JSON.parse(io)
                if isa(res, Vector{Any})
                    existing_data = res
                else
                    existing_data = [res]
                end
            end
        catch
            []
        end
    else
        []
    end

    return existing_data
end

function dict_to_trial_entry(d::Dict)::TrialEntry
    TrialEntry(d["warmup_results"], d["versions"], d["benchmarktools_parameters"], d["results"], d["metadata"], d["experiment_parameters"], get(d, "machine_info", Dict()))
end
dicts_to_trial_entries(dicts::Vector{Dict})::Vector{TrialEntry} = map(dict_to_trial_entry, dicts)
get_trial_entries_from_file(filename::AbstractString)::Vector{TrialEntry} = dicts_to_trial_entries(load_db_file_to_dicts(filename))


# Converting trials to trial entries

function trial_to_dict(t::BenchmarkTools.Trial)
    function trial_format_results(trial_json)::Dict
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

    # Generate new dict from BenchmarkTools.Trial object
    buffer = IOBuffer()
    BenchmarkTools.save(buffer, t)
    return trial_format_results(JSON.parse(String(take!(buffer))))
end

function trial_add_worker_parameters(trial_dict::Dict, parameters::Dict)
    merge!(trial_dict, parameters)
    trial_dict
end

convert(::Type{Dict}, t::BenchmarkTools.Trial)::Dict = trial_to_dict(t)
convert(::Type{Dict}, t::BenchmarkTools.Trial, parameters::Dict)::Dict = convert(Dict, t) |> (x -> trial_add_worker_parameters(x, parameters))
convert(::Type{TrialEntry}, t::BenchmarkTools.Trial, parameters::Dict)::TrialEntry = convert(Dict, t, parameters) |> dict_to_trial_entry


# Filtering entries

function filter_trial_entries(data::Vector{TrialEntry}, template::TrialEntry)::Vector{TrialEntry}
    return filter(entry -> is_fitting(entry, template), data)
end

function is_fitting(entry::TrialEntry, template::TrialEntry)
    for field in fieldnames(TrialEntry)
        entry_value = getfield(entry, field)
        template_value = getfield(template, field)

        if isa(template_value, Function)
            if template_value(entry_value) != true
                return false
            end
        elseif isa(template_value, Dict)
            if !is_matching_dict(entry_value, template_value)
                return false
            end
        else
            if entry_value != template_value
                return false
            end
        end
    end
    return true
end

function is_matching_dict(entry_dict::Dict, template_dict::Dict)
    for (key, template_value) in template_dict
        if haskey(entry_dict, key)
            entry_value = entry_dict[key]

            if isa(template_value, Function)
                if template_value(entry_value) != true
                    return false
                end
            elseif isa(template_value, Dict)
                if !is_matching_dict(entry_value, template_value)
                    return false
                end
            else
                if entry_value != template_value && template_value !== nothing
                    return false
                end
            end
        else
            return false
        end
    end
    return true
end


function trial_append_to_db(filename::AbstractString, t::BenchmarkTools.Trial, parameters::Dict)
    filename = joinpath(DB_DIR, filename)

    data = load_db_file_to_dicts(filename)

    new_entry = convert(Dict, t, parameters)

    push!(data, new_entry)

    open(filename, "w") do io
        JSON.print(io, data, 2)
    end
end
