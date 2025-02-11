using JSON
using Statistics
using Plots

function import_results(file::String)::Dict{Int, Vector{Float64}}
    local results::Dict{Int, Vector{Float64}}
    open("benchmark_results/$file") do io
        parsed_data = JSON.parse(io)
        results = Dict(parse(Int, k) => v for (k, v) in parsed_data)
    end
    results
end

function plot_strong_scalability(results::Dict{Int, Vector{Float64}})
    # Prepare data for plotting
    thread_counts = collect(keys(results))
    execution_means = [mean(filter(!isnothing, results[t])) for t in thread_counts]  # Mean execution times
    execution_stds = [std(filter(!isnothing, results[t])) for t in thread_counts]    # Standard deviations

    plot(thread_counts, execution_means, seriestype=:scatter,
                yerror=execution_stds,
                xlabel="Worker threads", ylabel="Execution time (s)",
                title="Execution Time vs. Worker Threads",
                marker=:circle, markersize=6, legend=false,
                xticks=(thread_counts, string.(thread_counts)))
end

results_filename = "benchmark_results_2025-02-10_05-55-06.json"
res = import_results(results_filename)

strong_scalability_p = plot_strong_scalability(res)

filename = "strong_scalability_plot.png"
savefig(strong_scalability_p, filename)
println("Strong scalability_plot saved as $filename")

display(strong_scalability_p)

sleep(10)
