using .FrameworkDemoPipelineExperiments

struct FrameworkDemoEPG <:ExperimentParametersGenerator
    experiment::AbstractExperiment
    parameters::BenchmarkParameters
    threads_min_num::Int
    threads_max_num::Int
    concurrent_min_num::Int
    concurrent_max_num::Int
    crunch_coefficients::Union{Nothing, Vector{Float64}}
    repeated_crunch_calibration::Bool

    function FrameworkDemoEPG(experiment::AbstractExperiment, parameters::BenchmarkParameters, threads_min_num::Int, threads_max_num::Int, concurrent_min_num::Int, concurrent_max_num::Int, repeated_crunch_calibration::Bool, fast::Bool)
        if (!repeated_crunch_calibration)
            println("Crunch coefficients will be calibrated only once.")
            if fast
                crunch_coefficients = nothing
            else
                crunch_coefficients = collect(collect(FrameworkDemo.calibrate_crunch(; fast = fast))[1])
            end
        else
            println("Crunch coefficients will be calibrated for each experiment.")
            crunch_coefficients = nothing
        end

        experiment_ = deepcopy(experiment)
        experiment_.crunch_coefficients = crunch_coefficients

        new(experiment, parameters, threads_min_num, threads_max_num, concurrent_min_num, concurrent_max_num, crunch_coefficients, repeated_crunch_calibration)
    end
end

function Base.iterate(epg::FrameworkDemoEPG, state = (epg.concurrent_min_num, epg.threads_min_num))
    concurrent, threads = state

    if threads > epg.threads_max_num
        return nothing
    end

    epg.parameters.threads_num = threads
    epg.experiment.max_concurrent_events = concurrent

    next_concurrent = concurrent + 1
    next_threads = threads

    if next_concurrent > epg.concurrent_max_num
        next_concurrent = epg.concurrent_min_num
        next_threads += 1
    end

    return ((epg.experiment, epg.parameters), (next_concurrent, next_threads))
end

Base.IteratorSize(::Type{FrameworkDemoEPG}) = Base.HasLength()
Base.length(epg::FrameworkDemoEPG) =
    (epg.concurrent_max_num - epg.concurrent_min_num + 1) *
    (epg.threads_max_num - epg.threads_min_num + 1)


mutable struct ExperimentsBookkeeper
    current_experiment_set::String
    conducted_experiments::Vector{String}
    crunch_coefficients::Vector{Float64}
end

function ExperimentsStateBookkeeper(new_experiment_set_name::Union{String, Nothing})
    new_experiment_set_name == "" && (new_experiment_set_name = nothing)
    mkpath("experiments_management")
    json_path = "experiments_management/current_experiment_state.json"

    local current_experiment_set::String
    local conducted_experiments::Vector{String}
    local crunch_coefficients::Vector{Float64}

    if (new_experiment_set_name === nothing)
        isfile(json_path) || error("Experiment is to be resumed, but there is no experiment state file.")
        content = open(json_path, "r") do f
            JSON.parse(read(f, String))
        end
        current_experiment_set = content["current_experiment_set"]
        conducted_experiments = content["conducted_experiments"]
        crunch_coefficients = content["crunch_coefficients"]
    else
        current_experiment_set = new_experiment_set_name
        conducted_experiments = []
        crunch_coefficients = collect(collect(FrameworkDemo.calibrate_crunch(; fast = false))[1])

        file_content = Dict(
            "current_experiment_set" => current_experiment_set,
            "conducted_experiments" => conducted_experiments,
            "crunch_coefficients" => crunch_coefficients
        )
        if isfile(json_path)
            timestamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM-SS")
            backup_path = "experiments_management/current_experiment_state.$timestamp.json"
            cp(json_path, backup_path; force=true)
        end
        open(json_path, "w") do f
            JSON.print(f, file_content, 4)
        end
    end
    ExperimentsBookkeeper(current_experiment_set, conducted_experiments, crunch_coefficients)
end

function get_experiment_set(experiment_set_name::String; filename::String="experiments_management/experiments_sets.json")
    open(filename, "r") do f
        content = JSON.parse(read(f, String))
        for e in content
            if e["name"] == experiment_set_name
                return e
            end
        end
        return nothing
    end
end

function get_random_experiment(bookkeeper::ExperimentsBookkeeper; filename::String="experiments_management/experiments_sets.json")
    experiment_set = get_experiment_set(bookkeeper.current_experiment_set; filename=filename) # TODO: check for "nothing"

    all_experiments = experiment_set["experiments"]
    all_ids = [e["id"] for e in all_experiments]

    remaining_ids = setdiff(all_ids, bookkeeper.conducted_experiments)

    isempty(remaining_ids) && return (nothing, nothing)

    selected_id = rand(remaining_ids)

    selected_experiment = filter(e -> e["id"] == selected_id, all_experiments)[1]

    return (selected_id, selected_experiment)
end

function finalize!(bookkeeper::ExperimentsBookkeeper, experiment_id::String)
    push!(bookkeeper.conducted_experiments, experiment_id)

    file_content = Dict(
        "current_experiment_set" => bookkeeper.current_experiment_set,
        "conducted_experiments" => bookkeeper.conducted_experiments,
        "crunch_coefficients" => bookkeeper.crunch_coefficients
    )

    open("experiments_management/current_experiment_state.json", "w") do f
        JSON.print(f, file_content, 4)
    end
end


mutable struct RandomFrameworkDemoEPG
    parameters::BenchmarkParameters
    bookkeeper::ExperimentsBookkeeper
    last_experiment_id::Union{Nothing, String}
end

function Base.iterate(epg::RandomFrameworkDemoEPG, state=nothing)
    id, exp_data = get_random_experiment(epg.bookkeeper)
    isnothing(id) && return nothing
    epg.last_experiment_id = id

    experiment = FrameworkDemoPipelineExperiment(
        exp_data["data_flow"],
        exp_data["event_count"],
        exp_data["max_concurrent_events"],
        get(exp_data, "fast", false),
        nothing,
        epg.bookkeeper.crunch_coefficients
    )

    epg.parameters.threads_num = exp_data["threads_num"]

    return ((experiment, epg.parameters), nothing)
end

Base.IteratorSize(::Type{RandomFrameworkDemoEPG}) = Base.SizeUnknown()

function finalize!(epg::RandomFrameworkDemoEPG)
    id = epg.last_experiment_id
    id === nothing && error("No experiment has been selected yet.")
    finalize!(epg.bookkeeper, id)
end
