# using FrameworkDemo
using BenchmarkParallel
using BenchmarkParallel.BenchmarkParallelUtils
using BenchmarkParallel.JSON
using BenchmarkParallel.ArgParse
using BenchmarkParallel.Dates
using BenchmarkParallel.UUIDs

using BenchmarkParallel.BenchmarkTools
using BenchmarkParallel.BenchmarkPlots, BenchmarkParallel.StatsPlots

using BenchmarkParallel.Logging
using BenchmarkParallel.Serialization


const PROGRAM_VERSION = "0.12"

implementation = ENV["JULIA_PARALLEL_TEST_IMPL_M"]
ImplModule = include(implementation)
using .ImplModule


function parse_args(raw_args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--machine-info-filename"
        help = "Machine info will be retrieved from this file"
        arg_type = String
        default = "machine_info.json"
    end

    return ArgParse.parse_args(raw_args, s)
end

function warmup(experiment::AbstractExperiment)
    @custom_exitcode_on_error begin
        @elapsed @eval run_experiment($experiment)
    end errmsg="Error during task warmup execution!" exitcode=43
end

function do_benchmarks(experiment::AbstractExperiment, b_p::BenchmarkParameters)
    b = @benchmarkable run_experiment($experiment) seconds = b_p.timeout samples = b_p.samples evals = b_p.evals

    @custom_exitcode_on_error begin
        run(b)
    end errmsg="Error during task execution!" exitcode=44
end

function benchmark_experiment(par::AllParams)
    meta::BenchmarkMetadata = BenchmarkMetadata(PROGRAM_VERSION)

    # Setup
    setup_experiment(par.experiment)

    # Warmup run
    execution_time_with_precompilation = warmup(par.experiment)
    println("Execution time with precompilation: $execution_time_with_precompilation")

    register_start_time(meta)
    # Measurements
    trial = do_benchmarks(par.experiment, par.benchmark_parameters)
    register_end_time(meta)

    # Teardown
    teardown_experiment(par.experiment)

    println("Trial results:")
    println(trial)

    # Save results
    # save_violin_plot(t)
    res = BenchmarkResults(trial, execution_time_with_precompilation)
    entry = TrialEntry(res, par, meta)
    trial_append_to_db(par.benchmark_parameters.results_filename, entry)

    0
end

function (@main)(raw_args)
    args = parse_args(raw_args)
    machine_info_filename::String = args["machine-info-filename"]

    experiment::AbstractExperiment = deserialize(stdin) # Receive experiment object from launcher
    benchmark_parameters::BenchmarkParameters = deserialize(stdin) # Receive parameters object from launcher
    machine_info::Dict = get_machine_info(machine_info_filename)

    parameters = AllParams(experiment, benchmark_parameters, machine_info)

    #TODO check the actual number of threads
    @info "Launching worker with benchmark params $parameters and experiment $experiment"


    if (benchmark_parameters.pin_threads)
        do_pin_threads()
    end

    @info "Worker started"
    benchmark_experiment(parameters)
end
