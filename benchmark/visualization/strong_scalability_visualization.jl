const STRONG_SCALABILITY_PLOTS_DIR = "strong_scalability_plots"

"""
Creates strong scalability plot
"""
function strong_scalability_routine(db, strong_scalability_plot_filename)
    # Create filter template
    versions = Dict()
    experiment_parameters = Dict(
        "thread_pinning" => true,
        "domain_parameters" => Dict(
            "event_count" => 200
        ),
        "threads_num" => x -> x < 33 ? true : false,
    )
    results = Dict()
    metadata = Dict()
    machine_info = Dict()

    template1 = TrialEntry(
        versions,
        experiment_parameters,
        results,
        metadata,
        machine_info)

    versions = Dict()
    experiment_parameters = Dict(
        "thread_pinning" => true,
        "domain_parameters" => Dict(
            "event_count" => 100,
            "max_concurrent" => 1,
        ),
        "threads_num" => 1
    )
    results = Dict()
    metadata = Dict()
    machine_info = Dict()
    template2 = TrialEntry(
        versions,
        experiment_parameters,
        results,
        metadata,
        machine_info)

    filtered_db1 = filter_trial_entries(db, template1)
    filtered_db2 = filter_trial_entries(db, template2)
    merged_filtered_db = vcat(filtered_db1, filtered_db2)

    println(length(db))
    println(length(merged_filtered_db))

    if (length(merged_filtered_db) > 0)
        gen_strong_scalability_plot(merged_filtered_db, STRONG_SCALABILITY_PLOTS_DIR,
        strong_scalability_plot_filename * ".pdf")
    end
end

function gen_strong_scalability_plot(data::Vector{TrialEntry}, dir, filename)
    create_and_save_plot(dir, filename, strong_scalability_plot, data)
end

"""
Expects the vector of filtered (meaning the same parameters) Trial entries and plots the strong scalability effect on throughput
"""
function strong_scalability_plot(data::Vector{TrialEntry}; bars::Bool = true, p = nothing)
    f = bars ? construct_scatter_plot_with_bars : construct_scatter_plot
    x_func = entry -> entry.experiment_parameters["threads_num"]
    y_func = entry -> begin
        execution_times = entry.results["execution_times"] / 1e9 # Convert to seconds
        event_count = entry.experiment_parameters["domain_parameters"]["event_count"]
        throughputs = event_count ./ execution_times
    end
    p = f(data,
    x_func,
    y_func,
    "Threads Number",
    "Throughput, events/s",
    # "Strong Scalability Effect on Throughput",
    label = "Compiled code",
    p = p)

    p = f(data,
    entry -> entry.experiment_parameters["threads_num"],
    entry -> begin
        execution_times = entry.results["warmup_time"]
        event_count = entry.experiment_parameters["domain_parameters"]["event_count"]
        throughputs = event_count ./ execution_times
        t = [throughputs]
        # println(t)
        # println(typeof(t))
        return t
    end,
    label = "Warmup"
    ;
    color = :red,
    marker_type = :diamond,
    p=p)

    one_thread_data = Vector{Float64}()
    for entry in data
        key = x_func(entry)
        value = y_func(entry)

        if key == 1
            append!(one_thread_data, value)
        end
    end

    y_val = mode(one_thread_data)
    ideal_x = sort(unique(x_func.(data)))
    ideal_y = y_val .* ideal_x

    plot!(p, ideal_x, ideal_y; label = nothing, linestyle = :dash, color = :black)

    middle_index = round(Int, length(ideal_x) / 2)

    text_position_x = ideal_x[middle_index + 1]
    text_position_y = ideal_y[middle_index + 1]

    annotate!(p, text_position_x, text_position_y + 0.2, Plots.text("Ideal (linear) Speedup", 10, :center, rotation = 31))

    ylims!(p, (0, maximum(ideal_y) * 1.1))
    yticks!(p, 0:0.4:maximum(ideal_y) * 1.2)
    p
end
