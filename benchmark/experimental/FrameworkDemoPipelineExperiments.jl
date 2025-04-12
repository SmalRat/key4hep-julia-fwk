module FrameworkDemoPipelineExperiments

using FrameworkDemo
using Logging
using Dates
using Dagger
using ..AbstractExperiments
import ..AbstractExperiments: AbstractExperiment, setup_experiment, run_experiment, teardown_experiment, get_version, get_experiment_parameters

mutable struct FrameworkDemoPipelineExperiment <: AbstractExperiment
    data_flow_name::String
    event_count::Int
    max_concurrent_events::Int
    fast::Bool
    df::Union{Nothing, FrameworkDemo.DataFlowGraph} #TODO: leave uninitialized
    crunch_coefficients::Union{Vector{Float64}, Dagger.Shard, Nothing} #TODO
end

function setup_experiment(x::FrameworkDemoPipelineExperiment)
    # Configure logs
    FrameworkDemo.disable_tracing!() # Disables internal Dagger logging mechanism
    Logging.disable_logging(Logging.Info) # Disables all Julia "debug" and "info" logs completely
    mkpath("logs")
    logs_filename = "logs/Worker_logfile_" * Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM-SS") * ".log"
    FrameworkDemo.redirect_logs_to_file(open(logs_filename, "a"))
    println("Logs are redirected to $logs_filename.")

    # Load data-flow graph
    path = joinpath(pkgdir(FrameworkDemo), "data/$(x.data_flow_name)/df.graphml")
    graph = FrameworkDemo.parse_graphml(path)
    x.df = FrameworkDemo.mockup_dataflow(graph)

    # Calibrate crunching if needed
    if (x.crunch_coefficients === nothing)
        x.crunch_coefficients = FrameworkDemo.calibrate_crunch(; fast = x.fast)
        println("Calibrated crunch coefficients")
    else
        x.crunch_coefficients = Dagger.@shard x.crunch_coefficients
    end

end

function run_experiment(x::FrameworkDemoPipelineExperiment)
    FrameworkDemo.run_pipeline(x.df;
            event_count = x.event_count,
            max_concurrent = x.max_concurrent_events,
            crunch_coefficients = x.crunch_coefficients)
end

teardown_experiment(x::FrameworkDemoPipelineExperiment) = nothing

get_version(x::FrameworkDemoPipelineExperiment) = "0.1.1"

get_experiment_parameters(x::FrameworkDemoPipelineExperiment) = Dict(
    "data_flow_name" => x.data_flow_name,
    "event_count" => x.event_count,
    "max_concurrent" => x.max_concurrent_events,
    "fast" => x.fast,
    "crunch_coefficients" => if x.crunch_coefficients isa Dagger.Shard
                                collect(collect(x.crunch_coefficients)[1])
                            else
                                x.crunch_coefficients
                            end
)

export FrameworkDemoPipelineExperiment, setup_experiment, run_experiment, teardown_experiment, get_version, get_experiment_parameters

end

return FrameworkDemoPipelineExperiments
