using FrameworkDemo

include("launch.jl")


include("FrameworkDemoPipelineExperiments.jl")
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
end

function get_experiment_set(experiment_set_name::String; filename::String="experiments_management/experiment_sets.json")
    open(filename, "r") do f
        content = JSON.parse(read(f, String))
        experiment_set = content[experiment_set_name]
        return experiment_set
    end
end

function ExperimentsStateBookkeeper(; new_experiment_set_name::Union{String, Nothing} = nothing)
    mkpath("experiments_management")

    current_experiment_set::String
    conducted_experiments::Vector{String}

    if (new_experiment_set_name === nothing)
        isfile("experiments_management/current_experiment_state.json") || error("Experiment is to be resumed, but there is no experiment state file.")
        content = open("experiments_management/current_experiment_state.json", "r") do f
            JSON.parse(read(f, String))
        end
        current_experiment_set = content["current_experiment_set"]
        conducted_experiments = content["conducted_experiments"]
    else
        current_experiment_set = new_experiment_set_name
        conducted_experiments = []
        file_content = Dict(
            "current_experiment_set" => current_experiment_set,
            "conducted_experiments" => conducted_experiments
        )
        open("experiments_management/current_experiment_state.json", "w") do f
            write(f, JSON.print(file_content), 4)
        end
    end
    new(current_experiment_set, conducted_experiments)
end

# function get_next_experiment(bookkeeper::ExperimentsStateBookkeeper)

# end

function parse_args(raw_args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        "data-flow"
        help = "Input data-flow graph as a GraphML file"
        arg_type = String
        required = true

        "results-filename"
        help = "Benchmark results will be stored in this file"
        arg_type = String
        required = true

        "--errors-log-filename"
        help = "File to redirect workers' stderr output"
        arg_type = String
        default = "error_log.txt"

        "--samples"
        help = "Number of samples for each thread count"
        arg_type = Int
        default = 1

        "--min-threads"
        help = "Minimum number of threads to test"
        arg_type = Int
        default = 1

        "--max-threads"
        help = "Maximum number of threads to test"
        arg_type = Int
        default = 4

        "--event-count"
        help = "Number of events to be processed"
        arg_type = Int
        default = 1

        "--max-concurrent-low"
        help = "Number of slots for graphs to be scheduled concurrently (lower bound)"
        arg_type = Int
        default = 1

        "--max-concurrent-high"
        help = "Number of slots for graphs to be scheduled concurrently (upper bound)"
        arg_type = Int
        default = 1

        "--fast"
        help = "Execute algorithms immediately skipping algorithm runtime information and crunching"
        action = :store_true

        "--repeated-crunch-calibration"
        help = "Execute algorithms immediately skipping algorithm runtime information and crunching"
        action = :store_true

        "--pin-threads"
        help = "Pin Julia threads to CPU threads"
        arg_type = Bool
        default = false

        "--relaunch-on-error"
        help = "Relaunch worker script on error"
        arg_type = Bool
        default = false
    end

    return ArgParse.parse_args(raw_args, s)
end


function (@main)(raw_args)
    args = parse_args(raw_args)

    pin_threads = args["pin-threads"]
    samples = args["samples"]
    min_threads = args["min-threads"]
    max_threads = args["max-threads"]

    data_flow = args["data-flow"]
    event_count = args["event-count"]
    concurrent_low = args["max-concurrent-low"]
    concurrent_high = args["max-concurrent-high"]
    fast = args["fast"]
    repeated_crunch_calibration = args["repeated-crunch-calibration"]
    relaunch_on_error = args["relaunch-on-error"]

    results_filename = args["results-filename"]
    errors_log_filename = args["errors-log-filename"]

    implementation = "FrameworkDemoPipelineExperiments.jl"

    experiment = FrameworkDemoPipelineExperiment(data_flow, event_count, concurrent_low, fast, nothing, nothing)
    parameters = BenchmarkParameters(
        results_filename,
        pin_threads=pin_threads,
        samples=samples,
    )
    epg = FrameworkDemoEPG(experiment, parameters, min_threads, max_threads, concurrent_low, concurrent_high, repeated_crunch_calibration, fast)

    for (exp, params) in epg
        println("Running with $(params.threads_num) threads on experiment $(exp)...")
        launcher(exp, params, implementation, errors_log_filename, relaunch_on_error)
    end
end
