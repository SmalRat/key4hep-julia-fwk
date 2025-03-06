using ArgParse

# Example cmd line command:
# julia --project=. launcher.jl demo/parallel results.json --samples=2 --min-threads=8 --max-threads=9 --event-count=20 --max-concurrent=10

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

    end

    return ArgParse.parse_args(raw_args, s)
end


function (@main)(raw_args)
    args = parse_args(raw_args)

    samples = args["samples"]
    min_threads = args["min-threads"]
    max_threads = args["max-threads"]

    data_flow = args["data-flow"]
    event_count = args["event-count"]
    concurrent_low = args["max-concurrent-low"]
    concurrent_high = args["max-concurrent-high"]
    fast = args["fast"]

    results_filename = args["results-filename"]

    for t in min_threads:max_threads
        for c in concurrent_low:concurrent_high
            println("Adding a new worker process with $t threads and concurrency number: $c...")

            worker_cmd = Cmd(`julia --threads=$t --project=. worker.jl $data_flow $results_filename --event-count=$event_count --max-concurrent=$c --samples=$samples --fast=$fast`)
            run(worker_cmd)

            println("Worker with $t threads and concurrency number: $c exited.")
        end
    end
end
