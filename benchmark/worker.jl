using FrameworkDemo
using JSON
using ArgParse

using BenchmarkTools
using BenchmarkPlots, StatsPlots


const PROGRAM_VERSION = "0.0"
const RESULTS_DIR = "benchmark_results"


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

function append_save(filename::AbstractString, t::BenchmarkTools.Trial, parameters::Dict)
    endswith(filename, ".json") || badext(filename)

    mkpath(RESULTS_DIR)
    filename = joinpath(RESULTS_DIR, filename)

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

    # Generate new JSON object from BenchmarkTools
    buffer = IOBuffer()
    BenchmarkTools.save(buffer, t)
    new_entry = JSON.parse(String(take!(buffer)))
    new_entry = push!(new_entry, parameters)

    push!(existing_data, new_entry)

    open(filename, "w") do io
        JSON.print(io, existing_data, 2)
    end
end

function compute_task(data_flow_name::String, results_filename::String, samples::Int, event_count::Int, max_concurrent::Int, fast::Bool)
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

    parameters = Dict(
        "samples" => samples,
        "event_count" => event_count,
        "max_concurrent" => max_concurrent,
        "fast" => fast,
        "data_flow" => data_flow_name
        )

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

    data_flow = args["data-flow"]
    results_filename = args["results-filename"]
    samples = args["samples"]
    event_count = args["event-count"]
    max_concurrent = args["max-concurrent"]

    fast = args["fast"]

    # Redirect logs to the file

    logfile = open("Worker_logfile.log", "a")
    FrameworkDemo.redirect_logs_to_file(logfile)
    @info "Worker started"

    res = compute_task(data_flow, results_filename, samples, event_count, max_concurrent, fast)
    println(JSON.json(Dict("result" => res)))
end
