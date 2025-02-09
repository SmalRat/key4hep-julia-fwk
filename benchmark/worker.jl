using FrameworkDemo
using JSON
using ArgParse

function parse_args(raw_args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        "data-flow"
        help = "Input data-flow graph as a GraphML file"
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

        "--fast"
        help = "Execute algorithms immediately skipping algorithm runtime information and crunching"
        arg_type = Bool
        default = false
    end

    return ArgParse.parse_args(raw_args, s)
end

function compute_task(data_flow_name::String, event_count::Int, max_concurrent::Int, fast::Bool)
    path = joinpath(pkgdir(FrameworkDemo), "data/demo/$(data_flow_name)/df.graphml")
    graph = FrameworkDemo.parse_graphml(path)
    df = FrameworkDemo.mockup_dataflow(graph)

    t = @elapsed FrameworkDemo.run_pipeline(df;
    event_count = event_count,
    max_concurrent = max_concurrent,
    fast = fast)

    return t
end

function (@main)(raw_args)
    args = parse_args(raw_args)

    data_flow = args["data-flow"]
    event_count = args["event-count"]
    max_concurrent = args["max-concurrent"]

    fast = args["fast"]

    # Redirect logs to the file

    logfile = open("Worker_logfile.log", "a")
    FrameworkDemo.redirect_logs_to_file(logfile)
    @info "Worker started"

    res = compute_task(data_flow, event_count, max_concurrent, fast)
    println(JSON.json(Dict("result" => res)))
end
