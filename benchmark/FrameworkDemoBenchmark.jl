# How to run?
# > julia --project=. FrameworkDemoBenchmark.jl test.json --samples=1 --pin-threads=true --relaunch-on-error=true --new-experiment-set=experiments_set_4

include("launch.jl")

using FrameworkDemo

include("FrameworkDemoPipelineExperiments.jl")
using .FrameworkDemoPipelineExperiments

include("epg.jl")


function parse_args(raw_args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        # "data-flow"
        # help = "Input data-flow graph as a GraphML file"
        # arg_type = String
        # required = true

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

        # "--min-threads"
        # help = "Minimum number of threads to test"
        # arg_type = Int
        # default = 1

        # "--max-threads"
        # help = "Maximum number of threads to test"
        # arg_type = Int
        # default = 4

        # "--event-count"
        # help = "Number of events to be processed"
        # arg_type = Int
        # default = 1

        # "--max-concurrent-low"
        # help = "Number of slots for graphs to be scheduled concurrently (lower bound)"
        # arg_type = Int
        # default = 1

        # "--max-concurrent-high"
        # help = "Number of slots for graphs to be scheduled concurrently (upper bound)"
        # arg_type = Int
        # default = 1

        # "--fast"
        # help = "Execute algorithms immediately skipping algorithm runtime information and crunching"
        # action = :store_true

        # "--repeated-crunch-calibration"
        # help = "Execute algorithms immediately skipping algorithm runtime information and crunching"
        # action = :store_true

        "--pin-threads"
        help = "Pin Julia threads to CPU threads"
        arg_type = Bool
        default = false

        "--relaunch-on-error"
        help = "Relaunch worker script on error"
        arg_type = Bool
        default = false

        "--new-experiment-set"
        help = "Start a new experiment set"
        arg_type = String
        default = ""

        "--no-preserve-coefs"
        help = "Do not preserve crunch coefficients between experiments. By default, the coefficients are preserved if available."
        action = :store_true
    end

    return ArgParse.parse_args(raw_args, s)
end


function (@main)(raw_args)
    args = parse_args(raw_args)

    pin_threads = args["pin-threads"]
    samples = args["samples"]
    # min_threads = args["min-threads"]
    # max_threads = args["max-threads"]

    # data_flow = args["data-flow"]
    # event_count = args["event-count"]
    # concurrent_low = args["max-concurrent-low"]
    # concurrent_high = args["max-concurrent-high"]
    # fast = args["fast"]
    # repeated_crunch_calibration = args["repeated-crunch-calibration"]
    relaunch_on_error = args["relaunch-on-error"]

    results_filename = args["results-filename"]
    errors_log_filename = args["errors-log-filename"]

    new_experiment_set_name = args["new-experiment-set"]
    preserve_coefs = !args["no-preserve-coefs"]

    implementation = "FrameworkDemoPipelineExperiments.jl"
    parameters = BenchmarkParameters(
        results_filename,
        pin_threads=pin_threads,
        samples=samples,
    )

    bookkeeper = ExperimentsStateBookkeeper(new_experiment_set_name, preserve_coefs)
    epg = RandomFrameworkDemoEPG(parameters, bookkeeper, nothing)

    for (exp, params) in epg
        println("Running ", exp)
        println("with parameters ", params)
        launcher(exp, params, implementation, errors_log_filename, relaunch_on_error)

        finalize!(epg)
    end

    0
end
