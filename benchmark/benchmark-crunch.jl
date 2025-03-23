using FrameworkDemo
using BenchmarkTools
using ArgParse

function parse_args(raw_args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--calibrate-min-number"
        help = "Minimum number for calibration"
        arg_type = Int
        default = 1000

        "--calibrate-max-number"
        help = "Maximum number for calibration"
        arg_type = Int
        default = 200000

        "--crunch-seconds"
        help = "Number of seconds to run the crunching"
        arg_type = Float64
        default = 5.0
    end

    return ArgParse.parse_args(raw_args, s)
end

function (@main)(raw_args)
    args = parse_args(raw_args)

    calibrate_min_number::Int = args["calibrate-min-number"]
    calibrate_max_number::Int = args["calibrate-max-number"]
    crunch_seconds::Float64 = args["crunch-seconds"]

    t = benchmark_crunch(crunch_seconds, calibrate_min_number, calibrate_max_number)
    println("Result: ", t)
end

function calibrate(calibrate_min_number::Int, calibrate_max_number::Int)
    @info "Using calibration range" calibrate_min_number calibrate_max_number

    @time crunch_coefficients = FrameworkDemo.calculate_coefficients(calibrate_min_number, calibrate_max_number)
    @info "Calibrated crunch coefficients" crunch_coefficients
    @time crunch_coefficients = FrameworkDemo.calculate_coefficients(calibrate_min_number, calibrate_max_number)
    @info "Second time calibrated crunch coefficients" crunch_coefficients
    crunch_coefficients
end

function benchmark_crunch(crunch_seconds::Float64, calibrate_min_number::Int=1000, calibrate_max_number::Int=200_000)
    crunch_coefficients = calibrate(calibrate_min_number, calibrate_max_number)
    if crunch_coefficients isa Vector{Float64}
        p = @benchmarkable FrameworkDemo.crunch_for_seconds($crunch_seconds, $crunch_coefficients) samples = 30 evals = 1 seconds = 3600
        t = run(p)
        println(t)
        return t
    end
    return nothing
end
