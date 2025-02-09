using FrameworkDemo
using JSON

function compute_task(name::String)
    path = joinpath(pkgdir(FrameworkDemo), "data/demo/$(name)/df.graphml")
    graph = FrameworkDemo.parse_graphml(path)
    df = FrameworkDemo.mockup_dataflow(graph)
    event_count = 10
    max_concurrent = 4
    fast = true

    t = @elapsed FrameworkDemo.run_pipeline(df;
    event_count = event_count,
    max_concurrent = max_concurrent,
    fast = fast)

    return t
end

# Redirect logs to the file

logfile = open("Worker_logfile.log", "a")
FrameworkDemo.redirect_logs_to_file(logfile)
@info "Worker started"

res = compute_task("sequential")
println(JSON.json(Dict("result" => res)))
