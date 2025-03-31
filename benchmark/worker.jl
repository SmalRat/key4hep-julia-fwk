using FrameworkDemo
using JSON
using ArgParse
using Dates
using UUIDs
using ThreadPinning

using BenchmarkTools
using BenchmarkPlots, StatsPlots

using Logging

include("./db_tools.jl")

const PROGRAM_VERSION = "0.8"


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

        "--pin-threads"
        help = "Pin Julia threads to CPU threads"
        arg_type = Bool
        default = false
    end

    return ArgParse.parse_args(raw_args, s)
end

function do_pin_threads()
    println("Pinning Julia threads to CPU threads")
    cpu_threads = socket(1)
    num_julia_threads = Threads.nthreads()
    if (num_julia_threads > length(cpu_threads))
        println("Warning: number of Julia threads ($num_julia_threads) is greater than allocated CPU threads ($cpu_threads). Oversubscribing.")
        mult_factor = ceil(num_julia_threads / length(cpu_threads))
        cpu_threads = repeat(cpu_threads, Int(mult_factor))
    end
    pinthreads(cpu_threads) # Move to the CPU threads of the first socket
    pinthreads(:current) # Pin threads to the current CPU threads
end


function save_violin_plot(t::BenchmarkTools.Trial)
    p = plot(t)
    dir = "violin_benchmark_plots"
    mkpath(dir)
    cur_file_name = "violin_plot.png"
    savefig(p, dir * "/" * cur_file_name)
    println("Violin benchmark plot saved as $cur_file_name")
end


function compute_task(parameters::Dict)
    # Unpack parameters
    experiment_parameters = parameters["experiment_parameters"]
    data_flow_name = experiment_parameters["data_flow_name"]
    event_count = experiment_parameters["event_count"]
    max_concurrent = experiment_parameters["max_concurrent"]
    fast = experiment_parameters["fast"]
    samples = experiment_parameters["samples"]

    metadata = parameters["metadata"]
    results_filename = metadata["results_filename"]

    # Load data-flow graph
    path = joinpath(pkgdir(FrameworkDemo), "data/$(data_flow_name)/df.graphml")
    graph = FrameworkDemo.parse_graphml(path)
    df = FrameworkDemo.mockup_dataflow(graph)

    # Calibrate crunching
    crunch_coefficients = FrameworkDemo.calibrate_crunch(; fast = fast)

    # Configure logs
    FrameworkDemo.disable_tracing!() # Disables internal Dagger logging mechanism
    Logging.disable_logging(Logging.Info) # Disables all Julia "debug" and "info" logs completely
    mkpath("logs")
    FrameworkDemo.redirect_logs_to_file(open("logs/Worker_logfile_" * Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM-SS") * ".log", "a"))

    # Run pipeline with precompilation
    execution_time_with_precompilation = @elapsed FrameworkDemo.run_pipeline(df;
    event_count = event_count,
    max_concurrent = max_concurrent,
    crunch_coefficients = crunch_coefficients)
    println("Execution time with precompilation: $execution_time_with_precompilation")
    parameters["warmup_results"] = Dict("execution_time" => execution_time_with_precompilation)

    # Start experiment
    metadata["start_time"] = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")

    b = @benchmarkable FrameworkDemo.run_pipeline($df;
    event_count = $event_count,
    max_concurrent = $max_concurrent,
    crunch_coefficients = $crunch_coefficients) seconds = 172800 samples = samples evals = 1
    t = run(b)

    metadata["end_time"] = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
    metadata["UUID"] = string(UUIDs.uuid4())

    println("Trial results:")
    println(t)

    # Save results
    save_violin_plot(t)
    trial_append_to_db(results_filename, t, parameters)

    return t
end

function (@main)(raw_args)
    args = parse_args(raw_args)

    pin_threads::Bool = args["pin-threads"]
    if (pin_threads)
        do_pin_threads()
    end

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
            "threads_num" => threads_num,
            "thread_pinning" => pin_threads
        ),
        "metadata" => Dict(
            "benchmark_version" => PROGRAM_VERSION,
            "results_filename" => results_filename,
        ),
        )

    open("machine_info.json", "r") do io
        machine_info = JSON.parse(io)
        parameters["machine_info"] = machine_info
    end

    @info "Worker started"

    compute_task(parameters)

    return 0
end
