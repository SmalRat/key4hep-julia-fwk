using JSON
using Statistics
using Plots
using DataStructures
using Cairo
using FrameworkDemo
using ArgParse
using StatsBase

include("db_tools.jl")

"""
Script for visualizing benchmark results

Usage:
    julia visualization.jl results-filename=<results-filename> [--str-scal=<str-scal>] [--par-eff=<par-eff>] [--hist=<hist>] [--exec-plan=<exec-plan>] [--df-graph=<df-graph>]
Example:
    julia --project=. visualization.jl benchmark_results_2025-02-13_23-53-50.json --str-scal=strong_scalability_plot.png --par-eff=parallel_efficiency_plot.png --hist=histogram_plot.png --exec-plan=execution_plan.png --df-graph=../data/demo/sequential/df.graphml
"""

const CONCURRENCY_EFFECT_PLOTS_DIR = "concurrency_effect_plots"

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

function draw_execution_plan(path::String, save_path::String)
    graph = FrameworkDemo.parse_graphml(path)
    df = FrameworkDemo.mockup_dataflow(graph)
    FrameworkDemo.save_execution_plan(df, save_path)
end

"""
Expects the vector of filtered (meaning the same parameters) Trial entries and plots the concurrency effect on execution time
"""
function concurrency_effect_plot(data::Vector{TrialEntry})
    grouped_data = Dict{Int, Vector{Float64}}()

    for entry in data
        max_concurrent = entry.experiment_parameters["max_concurrent"]
        execution_times = entry.results["execution_times"] / 1e9 # Convert to seconds
        event_count = entry.experiment_parameters["event_count"]

        throughputs = event_count ./ execution_times

        if haskey(grouped_data, max_concurrent)
            append!(grouped_data[max_concurrent], throughputs)
        else
            grouped_data[max_concurrent] = copy(throughputs)
        end
    end

    # Compute mode of execution times for each max_concurrent value
    x_vals = sort(collect(keys(grouped_data)))
    y_vals = [mode(grouped_data[k]) for k in x_vals]

    scatter(x_vals, y_vals, xlabel="Max Concurrent Events", ylabel="Throughput, events/s",
            title="Concurrency Effect on Execution Time", legend=false, markersize=6,
            ylims=(0, 1.1*maximum(y_vals)))
end

function create_and_save_plot(dir, filename, f, data...)
    if !isnothing(filename)
        p = f(data...)
        mkpath(dir)
        savefig(p, dir * "/" * filename)
        println("Plot saved as $(dir * "/" * filename)")
    end
end

function gen_concurrency_effect_plot(data::Vector{TrialEntry}, dir, filename)
    create_and_save_plot(dir, filename, concurrency_effect_plot, data)
end

function parse_args(raw_args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        "results-filename"
        help = "Results file to visualize"
        arg_type = String
        required = true

        "--str-scal"
        help = "Strong scalability plot filename"
        arg_type = String
        default = nothing

        "--par-eff"
        help = "Parallel efficiency plot filename"
        arg_type = String
        default = nothing

        "--hist"
        help = "Histogram plot filename"
        arg_type = String
        default = nothing

        "--conc-eff"
        help = "Concurrency efficiency plot filename"
        arg_type = String
        default = nothing

        "--exec-plan"
        help = "Execution plan graph filename"
        arg_type = String
        default = nothing

        "--df-graph"
        help = "Data flow graph filename"
        arg_type = String
        default = nothing
    end

    return ArgParse.parse_args(raw_args, s)
end

function filter_entries(db, filter_args::Dict)
    # Filter entries by experiment parameters
    data = filter_by_experiment_parameters(db, "event_count", filter_args["event_count"])
    data = filter_by_experiment_parameters(data, "samples", filter_args["samples"])
    data = filter_by_experiment_parameters(data, "data_flow_name", filter_args["data_flow_name"])
    data = filter_by_experiment_parameters(data, "threads_num", filter_args["threads_num"])

    # Filter entries by version
    data = filter_by_version(data, "Julia", filter_args["julia_version"])
    # data = filter_by_version(data, "BenchmarkTools", "")

    # Filter entries by BenchmarkTools parameters

    data
end


function (@main)(raw_args)
    args = parse_args(raw_args)

    results_filename = args["results-filename"]
    strong_scalability_plot_filename = args["str-scal"]
    parallel_efficiency_plot_filename = args["par-eff"]
    histogram_plot_filename = args["hist"]
    concurrency_effect_plot_filename = args["conc-eff"]

    execution_plan_path = args["exec-plan"]
    df_graph_path = args["df-graph"]


    # Filter entries by parameters
    db = load_db_file("benchmark_results/results.json")
    filter_args = Dict("event_count" => 100,
    "samples" => 5,
    "data_flow_name" => "ATLAS/q449",
    "threads_num" => 5,
    "julia_version" => "1.11.3")
    filtered_db = filter_entries(db, filter_args)
    trial_entries = dicts_to_trial_entries(filtered_db)


    gen_concurrency_effect_plot(trial_entries, CONCURRENCY_EFFECT_PLOTS_DIR,
     concurrency_effect_plot_filename)

    # concurrency_effect_p = concurrency_effect_plot(trial_entries)
    # savefig(concurrency_effect_p, "concurrency_effect_plot.png")
    # println("Concurrency effect plot saved as concurrency_effect_plot.png")

    # if !isnothing(strong_scalability_plot_filename)
    #     strong_scalability_p = plot_strong_scalability(res)
    #     dir = "strong_scalability_plots"
    #     mkpath(dir)
    #     savefig(strong_scalability_p, dir * "/" * strong_scalability_plot_filename)
    #     println("Strong scalability_plot saved as $strong_scalability_plot_filename")
    # end

    # if !isnothing(strong_scalability_plot_filename)
    #     strong_scalability_p = plot_strong_scalability(res)
    #     dir = "strong_scalability_plots"
    #     mkpath(dir)
    #     savefig(strong_scalability_p, dir * "/" * strong_scalability_plot_filename)
    #     println("Strong scalability_plot saved as $strong_scalability_plot_filename")
    # end

    # if !isnothing(parallel_efficiency_plot_filename)
    #     parallel_efficiency_p = plot_parallel_efficiency(res)
    #     dir = "parallel_efficiency_plots"
    #     mkpath(dir)
    #     savefig(parallel_efficiency_p, dir * "/" *  parallel_efficiency_plot_filename)
    #     println("Parallel efficiency_plot saved as $parallel_efficiency_plot_filename")
    # end

    # if !isnothing(histogram_plot_filename)
    #     for threads_count in keys(res)
    #         histogram_p = plot_histogram_for_thread_count(res, threads_count)
    #         dir = "histogram_plots"
    #         mkpath(dir)
    #         cur_file_name = histogram_plot_filename * "_$threads_count" * ".png"
    #         savefig(histogram_p, dir * "/" * cur_file_name)
    #         println("Histogram plot for $threads_count threads saved as $cur_file_name")
    #     end
    # end

    # if !isnothing(execution_plan_path) && !isnothing(df_graph_path)
    #     dir = "execution_plans"
    #     mkpath(dir)
    #     draw_execution_plan(df_graph_path, dir * "/" * execution_plan_path)
    #     println("Execution plan graph saved as $execution_plan_path")
    # end

    return 0
end
