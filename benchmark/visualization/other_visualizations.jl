function plot_strong_scalability(results::SortedDict{Int, Vector{Float64}})
    thread_counts = collect(keys(results))
    execution_means = [mean(filter(!isnothing, results[t])) for t in thread_counts]  # Mean execution times
    execution_stds = [std(filter(!isnothing, results[t])) for t in thread_counts]    # Standard deviations

    plot(thread_counts, execution_means, seriestype = :scatter,
         yerror = execution_stds,
         xlabel = "Worker threads", ylabel = "Execution time (s)",
         title = "Execution Time vs. Worker Threads",
         marker = :circle, markersize = 6, legend = false,
         xticks = (thread_counts, string.(thread_counts)),
         xlims = (0, maximum(thread_counts) + 1),
         ylims = (0, maximum(execution_means) + maximum(execution_stds)))
end

function plot_parallel_efficiency(results::SortedDict{Int, Vector{Float64}})
    thread_counts = collect(keys(results))

    reference_time = mean(results[1])  # Mean execution time for 1 thread

    # Calculate speedup for each thread count (Speedup = T(1) / T(N))
    speedups = [reference_time / mean(results[t]) for t in thread_counts]

    # Calculate parallel efficiency (Efficiency = Speedup / Threads)
    efficiencies = speedups ./ thread_counts

    p = plot(thread_counts, efficiencies, seriestype = :scatter, marker = :circle,
             markersize = 6,
             xlabel = "Worker threads", ylabel = "Parallel Efficiency",
             title = "Parallel Efficiency vs. Worker Threads", legend = false,
             xlim = (0, maximum(thread_counts) + 1),
             xticks = (thread_counts, string.(thread_counts)),
             ylim = (0, 1.1), yticks = 0:0.2:1.1)

    # Add line of efficiency as if 1 thread worked only
    plot!(p, thread_counts, 1 ./ thread_counts, label = "As if 1 thread works only (1/x)",
          linestyle = :dash)

    # Add the maximum possible efficiency line y = 1
    plot!(p, thread_counts, ones(length(thread_counts)), label = "Max Efficiency (1)",
          linestyle = :dot)
end

function plot_histogram_for_thread_count(results::SortedDict{Int, Vector{Float64}},
                                         thread_count::Int)
    execution_times = results[thread_count]

    histogram(execution_times, bins = 50, xlabel = "Execution Time (s)",
              ylabel = "Frequency",
              title = "Histogram of Execution Times for $thread_count Threads",
              legend = false)
end

function draw_execution_plan(path::String, save_path::String)
    graph = FrameworkDemo.parse_graphml(path)
    df = FrameworkDemo.mockup_dataflow(graph)
    FrameworkDemo.save_execution_plan(df, save_path)
end

function analyze_coefs_experiment(db, machine="machine", res_filename="analyze_coefs.txt")
    mkpath("experiments/analyze_coefs/$machine")
    open("experiments/analyze_coefs/$machine/$res_filename", "w") do io
        for entry in db
            print(io, entry.results["warmup_time"])
            print(io, " - ")
            println(io, entry.experiment_parameters["domain_parameters"]["crunch_coefficients"])
        end
    end
end
