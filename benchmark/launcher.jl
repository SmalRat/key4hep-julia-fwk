using ArgParse
using Dates

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
    relaunch_on_error = args["relaunch-on-error"]

    results_filename = args["results-filename"]
    errors_log_filename = args["errors-log-filename"]

    for t in min_threads:max_threads
        for c in concurrent_low:concurrent_high
            println("Adding a new worker process with $t threads and concurrency number: $c...")

            open(errors_log_filename, "a") do f_errors_log
                write(f_errors_log, "\n" * Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS" * "\n\n"))
                flush(f_errors_log)

                while (true)
                    worker_cmd = Cmd(`julia --threads=$t --project=. worker.jl $data_flow $results_filename --event-count=$event_count --max-concurrent=$c --samples=$samples --fast=$fast --pin-threads=$pin_threads`)
                    proc = run(pipeline(ignorestatus(worker_cmd), stderr=f_errors_log))
                    exit_code = proc.exitcode

                    if (exit_code == 0)
                        println("Worker with $t threads and concurrency number: $c finished successfully.")
                        break
                    elseif (exit_code != 43 && exit_code != 44)
                        println("Worker with $t threads and concurrency number: $c failed with exit code: $exit_code. Errors output saved to file $errors_log_filename.")
                        println("Exiting...")
                        break
                    else
                        println("Worker with $t threads and concurrency number: $c failed with exit code: $exit_code. Errors output saved to file $errors_log_filename.")
                        !relaunch_on_error && (println("Exiting..."); break)
                        println("Relaunching worker process with $t threads and concurrency number: $c...")
                    end
                end
            end
        end
    end
end
