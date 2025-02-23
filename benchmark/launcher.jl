using JSON
using ArgParse
using Dates
using Random


const PROGRAM_VERSION = "0.0"
const RESULTS_DIR = "benchmark_results"

function parse_args(raw_args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        "data-flow"
        help = "Input data-flow graph as a GraphML file"
        arg_type = String
        required = true

        "--results-filename"
        help = "Benchmark results will be stored in this file"
        arg_type = String
        required = true

        "--runs-number"
        help = "Number of runs for each thread count"
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

        "--max-concurrent"
        help = "Number of slots for graphs to be scheduled concurrently"
        arg_type = Int
        default = 1

        "--fast"
        help = "Execute algorithms immediately skipping algorithm runtime information and crunching"
        action = :store_true

    end

    return ArgParse.parse_args(raw_args, s)
end

function save_results(results::Dict, results_filename::String)
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    file_path = "$RESULTS_DIR/$results_filename"

    new_entry = Dict(
        "timestamp" => timestamp,
        "version" => PROGRAM_VERSION,
        "results" => results
    )

    existing_data = if isfile(file_path)
        try
            JSON.parsefile(file_path)
        catch
            []
        end
    else
        []
    end

    push!(existing_data, new_entry)

    open(file_path, "w") do io
        JSON.print(io, existing_data, 2)
    end

    println("Results saved to $file_path")
end

function (@main)(raw_args)
    args = parse_args(raw_args)

    run_repetitions = args["runs-number"]
    min_threads = args["min-threads"]
    max_threads = args["max-threads"]

    data_flow = args["data-flow"]
    event_count = args["event-count"]
    max_concurrent = args["max-concurrent"]
    fast = args["fast"]

    results_filename = args["results-filename"]

    mkpath("./$RESULTS_DIR")

    results = Dict()

    threads_list = repeat(min_threads:max_threads, run_repetitions)
    shuffled_threads = shuffle(threads_list)

    for t in min_threads:max_threads
        results[t] = []
    end

    for t in shuffled_threads
        println("Adding a new worker process with $t threads...")

        worker_cmd = Cmd(`julia --threads=$t --project=. worker.jl $data_flow --event-count=$event_count --max-concurrent=$max_concurrent --fast=$fast`)
        output = read(worker_cmd, String)

        println("Worker output: $output")

        parsed_result = try
            JSON.parse(output)["result"]
        catch e
            @warn "Failed to parse worker output: $e"
            nothing
        end

        push!(results[t], parsed_result)

        println("Execution time for $t threads: ", parsed_result)
    end

    save_results(results, results_filename)
end
