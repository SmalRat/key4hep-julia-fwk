using JSON
using Statistics
using Plots
using DataStructures

function import_results(file::String)::SortedDict{Int, Vector{Float64}}
    local results::SortedDict{Int, Vector{Float64}}
    open("benchmark_results/$file") do io
        parsed_data = JSON.parse(io)
        results = SortedDict(parse(Int, k) => v for (k, v) in parsed_data)
    end
    results
end

function plot_strong_scalability(results::SortedDict{Int, Vector{Float64}})

    thread_counts = collect(keys(results))
    execution_means = [mean(filter(!isnothing, results[t])) for t in thread_counts]  # Mean execution times
    execution_stds = [std(filter(!isnothing, results[t])) for t in thread_counts]    # Standard deviations

    plot(thread_counts, execution_means, seriestype=:scatter,
         yerror=execution_stds,
         xlabel="Worker threads", ylabel="Execution time (s)",
         title="Execution Time vs. Worker Threads",
         marker=:circle, markersize=6, legend=false,
         xticks=(thread_counts, string.(thread_counts)),
         xlims=(0, maximum(thread_counts) + 1),
         ylims=(0, maximum(execution_means) + maximum(execution_stds)))
end

function plot_parallel_efficiency(results::SortedDict{Int, Vector{Float64}})
    thread_counts = collect(keys(results))

    reference_time = mean(results[1])  # Mean execution time for 1 thread

    # Calculate speedup for each thread count (Speedup = T(1) / T(N))
    speedups = [reference_time / mean(results[t]) for t in thread_counts]

    # Calculate parallel efficiency (Efficiency = Speedup / Threads)
    efficiencies = speedups ./ thread_counts

    p = plot(thread_counts, efficiencies, seriestype=:scatter, marker=:circle, markersize=6,
             xlabel="Worker threads", ylabel="Parallel Efficiency",
             title="Parallel Efficiency vs. Worker Threads", legend=false,
             xlim = (0, maximum(thread_counts) + 1), xticks=(thread_counts, string.(thread_counts)),
             ylim=(0, 1.1), yticks=0:0.2:1.1)

    # Add line of efficiency as if 1 thread worked only
    plot!(p, thread_counts, 1 ./ thread_counts, label="As if 1 thread works only (1/x)", linestyle=:dash)

    # Add the maximum possible efficiency line y = 1
    plot!(p, thread_counts, ones(length(thread_counts)), label="Max Efficiency (1)", linestyle=:dot)
end

function plot_histogram_for_thread_count(results::SortedDict{Int, Vector{Float64}}, thread_count::Int)
    execution_times = results[thread_count]

    histogram(execution_times, bins=50, xlabel="Execution Time (s)", ylabel="Frequency",
                  title="Histogram of Execution Times for $thread_count Threads", legend=false)
end

results_filename = "benchmark_results_2025-02-10_05-55-06.json"
res = import_results(results_filename)

strong_scalability_p = plot_strong_scalability(res)
parallel_efficiency_p = plot_parallel_efficiency(res)
histogram_p = plot_histogram_for_thread_count(res, 8)

strong_scalability_plot_filename = "strong_scalability_plot.png"
parallel_efficiency_plot_filename = "parallel_efficiency_plot.png"
histogram_plot_filename = "histogram_plot.png"

savefig(strong_scalability_p, strong_scalability_plot_filename)
savefig(parallel_efficiency_p, parallel_efficiency_plot_filename)
savefig(histogram_p, histogram_plot_filename)

println("Strong scalability_plot saved as $strong_scalability_plot_filename")
println("Parallel efficiency_plot saved as $parallel_efficiency_plot_filename")
println("Histogram plot saved as $histogram_plot_filename")
