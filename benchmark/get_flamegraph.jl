# Script to get a flamegraph of the FrameworkDemo pipeline
# To get the flamegraph, run the following command:
# > include("get_flamegraph.jl")
# > get_profile_view(c, g, 100, 8) # c and g are preloaded in the script
# Warn: Julia may freeze, so start it with flag like -t 8,1 to add interactive thread


using FrameworkDemo
using Logging
using ProfileView

function get_graph(data_flow_name = "ATLAS/q449")
    # Load data-flow graph
    path = joinpath(pkgdir(FrameworkDemo), "data/$(data_flow_name)/df.graphml")
    graph = FrameworkDemo.parse_graphml(path)
    df = FrameworkDemo.mockup_dataflow(graph)
    df
end

function get_coefs()
    fast = false

    # Calibrate crunching
    crunch_coefficients = FrameworkDemo.calibrate_crunch(; fast = fast)
    crunch_coefficients
end

function run_graph(crunch_coefficients, df, event_count=100, max_concurrent=8)
    FrameworkDemo.run_pipeline(df;
    event_count = event_count,
    max_concurrent = max_concurrent,
    crunch_coefficients = crunch_coefficients)
end

function get_profile_view(crunch_coefficients, df, event_count=100, max_concurrent=8)
    @info "Running first time to compile"
    run_graph(crunch_coefficients, df, event_count, max_concurrent)
    @info "Running second time to profile"
    p = @profview run_graph(crunch_coefficients, df, event_count, max_concurrent)
    p
end

# Configure logs
FrameworkDemo.disable_tracing!() # Disables internal Dagger logging mechanism
Logging.disable_logging(Logging.Info) # Disables all Julia "debug" and "info" logs completely

c = get_coefs()
g = get_graph()
