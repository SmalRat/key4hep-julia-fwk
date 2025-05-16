const CRUNCH_EXPERIMENT_PLOTS_DIR = "crunch_experiment_plots"


"""
Expects the vector of filtered (meaning the same parameters) Trial entries and plots the histogram of execution times for the crunch experiment
"""
function crunch_experiment_plot(data::Vector{TrialEntry}; p = nothing)
    construct_histogram(data,
    entry -> begin
        execution_time = entry.results["warmup_time"]
    end,
    p = p,
    xlabel = "Execution Time, seconds",
    ylabel = "Frequency",
    # title = "Experiment Sample Execution Time Histogram"
    title = ""
    )
end


function gen_crunch_experiment_plot(data::Vector{TrialEntry}, dir, filename)
    create_and_save_plot(dir, filename, crunch_experiment_plot, data)
end

"""
Creates crunch experiment plot (histogram)
"""
function crunch_experiment_routine(db, crunch_experiment_plot_filename)
    versions = Dict()
    experiment_parameters = Dict()
    results = Dict()
    metadata = Dict()
    machine_info = Dict()

    template = TrialEntry(
        versions,
        experiment_parameters,
        results,
        metadata,
        machine_info)

    filtered_db = filter_trial_entries(db, template)

    if (length(filtered_db) > 0)
        gen_crunch_experiment_plot(filtered_db, CRUNCH_EXPERIMENT_PLOTS_DIR,
        crunch_experiment_plot_filename * ".pdf")
    end
end
