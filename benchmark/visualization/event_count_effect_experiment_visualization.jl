const EVENT_COUNT_EFFECT_PLOTS_DIR = "event_count_effect_plots"

function event_count_experiment_routine(db, event_count_effect_plot_filename)
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

    println(length(db))
    println(length(filtered_db))

    if (length(filtered_db) > 0)
        gen_event_count_effect_plot(filtered_db, EVENT_COUNT_EFFECT_PLOTS_DIR,
        event_count_effect_plot_filename * ".pdf")
    end
end

function gen_event_count_effect_plot(data::Vector{TrialEntry}, dir, filename)
    create_and_save_plot(dir, filename, event_count_effect_plot, data)
end

"""
Expects the vector of filtered (meaning the same parameters) Trial entries and plots the concurrency effect on throughput
"""
function event_count_effect_plot(data::Vector{TrialEntry}; bars::Bool = true, p = nothing)
    f = bars ? construct_scatter_plot_with_bars : construct_scatter_plot
    p = f(data,
    entry -> entry.experiment_parameters["domain_parameters"]["event_count"],
    entry -> begin
        execution_times = entry.results["execution_times"] / 1e9 # Convert to seconds
        event_count = entry.experiment_parameters["domain_parameters"]["event_count"]
        throughputs = event_count ./ execution_times
    end,
    "Total Events Number",
    "Throughput, events/s",
    label = "Compiled code",
    p = p)
    p = f(data,
    entry -> entry.experiment_parameters["domain_parameters"]["event_count"],
    entry -> begin
        execution_times = entry.results["warmup_time"]
        event_count = entry.experiment_parameters["domain_parameters"]["event_count"]
        throughputs = event_count ./ execution_times
        t = [throughputs]
        return t
    end,
    label = "Warmup"
    ;
    marker_type = :diamond,
    color = :red,
    p=p)
    p
end
