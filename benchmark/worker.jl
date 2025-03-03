using FrameworkDemo
using JSON
using ArgParse

using BenchmarkTools
using BenchmarkPlots, StatsPlots

include("./db_tools.jl")

const PROGRAM_VERSION = "0.2"


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

        "--event-count"
        help = "Number of events to be processed"
        arg_type = Int
        default = 1

        "--max-concurrent"
        help = "Number of slots for graphs to be scheduled concurrently"
        arg_type = Int
        default = 1

        "--samples"
        help = "Number of samples for each thread count"
        arg_type = Int
        default = 1

        "--fast"
        help = "Execute algorithms immediately skipping algorithm runtime information and crunching"
        arg_type = Bool
        default = false
    end

    return ArgParse.parse_args(raw_args, s)
end


function compute_task(parameters::Dict)
    experiment_parameters = parameters["experiment_parameters"]
    data_flow_name = experiment_parameters["data_flow_name"]
    event_count = experiment_parameters["event_count"]
    max_concurrent = experiment_parameters["max_concurrent"]
    fast = experiment_parameters["fast"]
    samples = experiment_parameters["samples"]

    metadata = parameters["metadata"]
    results_filename = metadata["results_filename"]

    path = joinpath(pkgdir(FrameworkDemo), "data/$(data_flow_name)/df.graphml")
    graph = FrameworkDemo.parse_graphml(path)
    df = FrameworkDemo.mockup_dataflow(graph)

    execution_time_with_precompilation = @elapsed FrameworkDemo.run_pipeline(df;
    event_count = event_count,
    max_concurrent = max_concurrent,
    fast = fast)

    println("Execution time with precompilation: $execution_time_with_precompilation")

    b = @benchmarkable FrameworkDemo.run_pipeline($df;
    event_count = $event_count,
    max_concurrent = $max_concurrent,
    fast = $fast) seconds = 3600 samples = samples evals = 1


    t = run(b)
    println("Trial results:")
    println(t)

    p = plot(t)
    dir = "violin_benchmark_plots"
    mkpath(dir)
    cur_file_name = "violin_plot.png"
    savefig(p, dir * "/" * cur_file_name)
    println("Violin benchmark plot saved as $cur_file_name")

    append_save(results_filename, t, parameters)

    return t
end

function (@main)(raw_args)
    args = parse_args(raw_args)

    data_flow_name::String = args["data-flow"]
    results_filename::String = args["results-filename"]
    samples::Int = args["samples"]
    event_count::Int = args["event-count"]
    max_concurrent::Int = args["max-concurrent"]
    threads_num::Int = Threads.nthreads()

    fast::Bool = args["fast"]

    parameters = Dict(
        "experiment_parameters" => Dict(
            "data_flow_name" => data_flow_name,
            "samples" => samples,
            "event_count" => event_count,
            "max_concurrent" => max_concurrent,
            "fast" => fast,
            "threads_num" => threads_num
        ),
        "metadata" => Dict(
            "benchmark_version" => PROGRAM_VERSION,
            "results_filename" => results_filename,
        ),
        )

    # Redirect logs to the file
    logfile = open("Worker_logfile.log", "a")
    FrameworkDemo.redirect_logs_to_file(logfile)
    @info "Worker started"

    compute_task(parameters)

    return 0
end
