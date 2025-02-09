using Distributed, Dagger, Plots

results = Dict()

# Launch workers one by one and wait for each to finish
for t in 1:4
    println("Adding a new worker process with $t threads...")

    # Add a worker with the specified thread count
    worker_id = addprocs(1; exeflags="--threads=$t")[1]

    @everywhere begin

    using FrameworkDemo
    using Dagger

    function compute_task(name::String)
        println("Running $(name) workflow demo")
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

        println("Worker $name output: ", t)
        return t
    end

    end

    # Execute the function remotely and fetch the result
    result = remotecall_fetch(compute_task, worker_id, "sequential")

    # Store result in the dictionary
    results[t] = result

    println("Execution time for $t threads: ", result)

    # Remove the worker after execution
    if length(workers()) > 1
        rmprocs!(Dagger.Sch.eager_context(), workers())
        workers() |> rmprocs |> wait
    end
end

# Plot results
thread_counts = collect(keys(results))
execution_times = collect(values(results))

p = plot(thread_counts, execution_times, seriestype=:scatter,
     xlabel="Worker threads", ylabel="Execution time, s", title="Execution time vs. worker threads",
     marker=:circle, markersize=6, legend=false)

filename = "worker_plot.png"
savefig(p, filename)
println("Plot saved as $filename")

display(p)

sleep(100)
