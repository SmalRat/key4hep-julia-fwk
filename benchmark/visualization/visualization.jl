using JSON
using Statistics
using Plots
using DataStructures
using Cairo
using FrameworkDemo
using ArgParse
using StatsBase
using BenchmarkParallel
using BenchmarkParallel.BenchmarkParallelUtils

include("visualization_utilities.jl")
include("strong_scalability_visualization.jl")
include("concurrency_effect_visualization.jl")
include("crunch_experiment_visualization.jl")
include("event_count_effect_experiment_visualization.jl")
include("other_visualizations.jl")

"""
Script for visualizing benchmark results

Usage:
    julia visualization.jl results-filename=<results-filename> [--str-scal=<plot_filename>] [--event-count-exp=<plot_filename>] [--conc-eff=<plot_filename>] [--crunch-exp=<plot_filename>]
Example (launch from the file directory):
    julia --project=.. visualization.jl ../benchmark_results/machine-2/results-machine-2-4.json --event-count-exp=plot_filename
    julia --project=.. visualization.jl ../benchmark_results/machine-2/merged.json --str-scal=plot_filename
    julia --project=.. visualization.jl ../benchmark_results/machine-2/results-machine-2-1.json --conc-eff=plot_filename
    julia --project=.. visualization.jl ../benchmark_results/machine-2/coefs-exp-machine-2.json --crunch-exp=plot_filename
"""


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

        "--conc-eff"
        help = "Concurrency efficiency plot filename"
        arg_type = String
        default = nothing

        "--crunch-exp"
        help = "Histogram plot filename for crunch experiment"
        arg_type = String
        default = nothing

        "--event-count-exp"
        help = "Scatter plot filename for event count experiment"
        arg_type = String
        default = nothing
    end

    return ArgParse.parse_args(raw_args, s)
end


function (@main)(raw_args)
    args = parse_args(raw_args)

    results_filename = args["results-filename"]
    strong_scalability_plot_filename = args["str-scal"]
    concurrency_effect_plot_filename = args["conc-eff"]
    crunch_experiment_plot_filename = args["crunch-exp"]
    event_count_experiment_plot_filename = args["event-count-exp"]

    # Filter entries by parameters
    db = get_trial_entries_from_file(results_filename)

    if (concurrency_effect_plot_filename !== nothing)
        concurrency_effect_routine(db, concurrency_effect_plot_filename)
    end

    if (strong_scalability_plot_filename !== nothing)
        strong_scalability_routine(db, strong_scalability_plot_filename)
    end

    if (crunch_experiment_plot_filename !== nothing)
        crunch_experiment_routine(db, crunch_experiment_plot_filename)
    end

    if (event_count_experiment_plot_filename !== nothing)
        event_count_experiment_routine(db, event_count_experiment_plot_filename)
    end

    return 0
end
