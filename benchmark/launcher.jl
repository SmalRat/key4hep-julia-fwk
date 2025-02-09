using Plots, JSON

results = Dict()

# Launch workers one by one and wait for each to finish
for t in 1:4
    println("Adding a new worker process with $t threads...")

    output = read(Cmd(`julia --threads=$t --project=. worker.jl`), String)

    println("Worker output: $output")

    parsed_result = try
        JSON.parse(output)["result"]
    catch e
        @warn "Failed to parse worker output: $e"
        nothing
    end

    # Store result in the dictionary
    results[t] = parsed_result

    println("Execution time for $t threads: ", parsed_result)
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
