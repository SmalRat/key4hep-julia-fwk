using BenchmarkTools
using JSON

const DB_DIR = "benchmark_results"

mutable struct TrialEntry
    versions::Dict
    experiment_parameters::Dict
    results::Dict
    metadata::Dict
    machine_info::Dict

    TrialEntry(versions::Dict, experiment_parameters::Dict, results::Dict, metadata::Dict, machine_info::Dict) = new(versions, experiment_parameters, results, metadata, machine_info)
end

function TrialEntry(r::BenchmarkResults, p::AllParams, m::BenchmarkMetadata)
    t_ = convert_(Dict, r.trial)
    experiment_version = get_version(p.experiment)
    domain_parameters = get_experiment_parameters(p.experiment)

    versions = merge!(t_["versions"], Dict("experiment_version" => experiment_version, "benchmark_version" => get_benchmark_version(m)))
    experiment_parameters = Dict("threads_num" => p.benchmark_parameters.threads_num, "thread_pinning" => p.benchmark_parameters.pin_threads, "domain_parameters" => domain_parameters, "benchmarktools_parameters" => t_["benchmarktools_parameters"])
    results = merge!(t_["results"], Dict("warmup_time" => r.warmup_time))
    metadata = convert_(Dict, m)
    machine_info = p.machine_info

    TrialEntry(versions, experiment_parameters, results, metadata, machine_info)
end

# Loading entries from file

#TODO check on start
badext(filename::String) = error("File $filename is not appropriate for db: it does not have a .json extension")

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
    TrialEntry(d["versions"],  d["experiment_parameters"], d["results"], d["metadata"], get(d, "machine_info", Dict()))
end
dicts_to_trial_entries(dicts::Vector{Dict})::Vector{TrialEntry} = map(dict_to_trial_entry, dicts)
get_trial_entries_from_file(filename::AbstractString)::Vector{TrialEntry} = dicts_to_trial_entries(load_db_file_to_dicts(filename))


# Converting trials to trial entries

function trial_to_dict(t::BenchmarkTools.Trial)::Dict
    # Generate new dict from BenchmarkTools.Trial object
    buffer = IOBuffer()
    BenchmarkTools.save(buffer, t)
    t_json = JSON.parse(String(take!(buffer)))

    version_info = t_json[1]

    trial_data = t_json[2][1][2]
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

convert_(::Type{Dict}, t::BenchmarkTools.Trial)::Dict = trial_to_dict(t)
convert_(::Type{Dict}, e::TrialEntry)::Dict = Dict(
    "versions" => e.versions,
    "experiment_parameters" => e.experiment_parameters,
    "results" => e.results,
    "metadata" => e.metadata,
    "machine_info" => e.machine_info
)

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


function trial_append_to_db(filename::AbstractString, new_entry::TrialEntry)
    filename = joinpath(DB_DIR, filename)

    data = load_db_file_to_dicts(filename)
    new_entry_dict = convert_(Dict, new_entry)
    push!(data, new_entry_dict)

    open(filename, "w") do io
        JSON.print(io, data, 2)
    end
end
