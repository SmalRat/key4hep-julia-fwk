const CONCURRENCY_EFFECT_PLOTS_DIR = "concurrency_effect_plots"

"""
Creates concurrency effect plots
"""
function concurrency_effect_routine(db, concurrency_effect_plot_filename)
    for threads_n in 1:16
        # Create filter template
        versions = Dict()
        experiment_parameters = Dict(
            "threads_num" => threads_n,
        )
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

        # analyze_coefs_experiment(filtered_db, "machine-4")

        if (length(filtered_db) > 0)
            gen_concurrency_effect_plot(filtered_db, CONCURRENCY_EFFECT_PLOTS_DIR,
            concurrency_effect_plot_filename * "_$(threads_n)_threads.pdf")
        end
    end

    function plot_many()
        local p = nothing
        color_map = Dict(
            1 => :red,
            5 => :blue,
            8 => :green,
            10 => :orange,
            12 => :purple,
            16 => :cyan
        )
        marker_map = Dict(
            1 => :circle,
            5 => :hexagon,
            8 => :rect,
            10 => :utriangle,
            12 => :diamond,
            16 => :+
        )
        for threads_n in (1, 5, 8, 10, 12, 16)
                # Create filter template
            versions = Dict()
            experiment_parameters = Dict(
                "threads_num" => threads_n,
            )
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
                plot_color = color_map[threads_n]
                marker_type = marker_map[threads_n]
                label_name = "Threads: $threads_n"

                p = concurrency_effect_plot(filtered_db, p = p, color = plot_color, marker_type = marker_type, label_name = label_name, title = "Concurrency Effect on Throughput, machine 4")
            end
        end
        if !isnothing(concurrency_effect_plot_filename)
            mkpath("../" * CONCURRENCY_EFFECT_PLOTS_DIR)
            savefig(p, "../" * CONCURRENCY_EFFECT_PLOTS_DIR * "/" * concurrency_effect_plot_filename * ".pdf")
            println("Plot saved as $(CONCURRENCY_EFFECT_PLOTS_DIR * "/" * concurrency_effect_plot_filename)")
        end
    end

    # plot_many()
end

function gen_concurrency_effect_plot(data::Vector{TrialEntry}, dir, filename)
    create_and_save_plot(dir, filename, concurrency_effect_plot, data)
end

"""
Expects the vector of filtered (meaning the same parameters) Trial entries and plots the concurrency effect on throughput
"""
function concurrency_effect_plot(data::Vector{TrialEntry}; bars::Bool = true, p = nothing, color = :blue, marker_type = :circle, label_name = nothing, title = nothing)
    f = bars ? construct_scatter_plot_with_bars : construct_scatter_plot
    f(data,
    entry -> entry.experiment_parameters["domain_parameters"]["max_concurrent"],
    entry -> begin
        execution_times = entry.results["execution_times"] / 1e9 # Convert to seconds
        event_count = entry.experiment_parameters["domain_parameters"]["event_count"]
        throughputs = event_count ./ execution_times
    end,
    "Max Concurrent Events",
    "Throughput, events/s",
    # (isnothing(title) ? "Concurrency Effect on Throughput, Threads Number: $(data[1].experiment_parameters["threads_num"])" : title),
    p = p,
    color = color,
    marker_type = marker_type,
    label = label_name)
end
