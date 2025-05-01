function construct_scatter_plot(data::Vector{TrialEntry}, x_func, y_func, xlabel = "X",
    ylabel = "Y", title = "Title")
    grouped_data = Dict{Int, Vector{Float64}}()

    for entry in data
        key = x_func(entry)
        value = y_func(entry)

        if haskey(grouped_data, key)
            append!(grouped_data[key], value)
        else
            grouped_data[key] = copy(value)
        end
    end

    x_vals = sort(collect(keys(grouped_data)))
    y_vals = [median(grouped_data[k]) for k in x_vals]

    scatter(x_vals,
    y_vals,
    xlabel = xlabel,
    ylabel = ylabel,
    title = title,
    titlefontsize = 10,
    legend = false,
    markersize = 5,
    ylims = (0, 1.1 * maximum(y_vals)))
end

function construct_scatter_plot_with_bars(data::Vector{TrialEntry}, x_func, y_func, xlabel = false,
    ylabel = false, title = false; p = nothing, color = :blue, marker_type = :circle, label = false)
    grouped_data = Dict{Int, Vector{Float64}}()

    for entry in data
        key = x_func(entry)
        value = y_func(entry)

        if haskey(grouped_data, key)
            append!(grouped_data[key], value)
        else
            grouped_data[key] = copy(value)
        end
    end

    x_vals = sort(collect(keys(grouped_data)))

    y_modes = [median(grouped_data[k]) for k in x_vals]
    y_stddevs = [std(grouped_data[k]) for k in x_vals]
    y_mins = [minimum(grouped_data[k]) for k in x_vals]
    y_maxs = [maximum(grouped_data[k]) for k in x_vals]
    max_y = maximum(y_maxs)
    max_y_mode = maximum(y_modes)

    y_err_lower_minmax = [median(grouped_data[k]) - minimum(grouped_data[k]) for k in x_vals]
    y_err_upper_minmax = [maximum(grouped_data[k]) - median(grouped_data[k]) for k in x_vals]

    y_err_std = (y_stddevs, y_stddevs)

    tick_step = 0.1
    max_y_rounded = round(max_y; digits = 3)
    y_max_tick = ceil(max_y / tick_step) * tick_step
    yticks_vals = sort(unique(0:tick_step:y_max_tick))

    legend = (label != false) ? true : false

    xlabel = xlabel != false ? xlabel : ""
    ylabel = ylabel != false ? ylabel : ""
    title = title != false ? title : ""

    # if label == "Warmup Time"
    #     y_err_std = nothing
    # end

    if p === nothing
        p = scatter(x_vals,
        y_modes,
        yerror = y_err_std,
        xlabel = xlabel,
        xlabelfontsize = 12,
        ylabel = ylabel,
        ylabelfontsize = 12,
        title = title,
        titlefontsize = 12,
        label = label,
        color = color,
        ylims = (0, 1.1 * maximum(y_maxs)),
        markersize = 3,
        legend = legend,
        xticks = x_vals,
        yticks = yticks_vals,
        grid = true,
        msc = :purple,
        markershape = marker_type)
    else
        current_ylims = Plots.ylims(p)
        current_yticks, _ = Plots.yticks(p)[1]

        scatter!(
            p,
            x_vals,
            y_modes,
            yerror = y_err_std,
            # xlabel = xlabel,
            xlabelfontsize = 12,
            # ylabel = ylabel,
            ylabelfontsize = 12,
            title = title,
            titlefontsize = 12,
            label = label,
            color = color,
            markersize = 3,
            legend = legend,
            xticks = x_vals,
            yticks = yticks_vals,
            grid = true,
            msc = :purple,
            markershape = marker_type
        )

        new_ymax = maximum([current_ylims[2], 1.1 * maximum(y_maxs)])
        Plots.ylims!(p, (0, new_ymax))

        # current_yticks = Plots.yticks(p)
        # current_yticks, _ = current_yticks[1]
        # current_yticks = collect(current_yticks)
        # println(current_yticks)
        # println(yticks_vals)

        new_yticks = union(current_yticks, yticks_vals) |> sort
        Plots.yticks!(p, new_yticks)
    end

    plot!(p, x_vals,
    y_modes,
    line = (:solid, 0.5, color),  # Adds solid lines, thickness 2, color blue
    label = false)

    # scatter!(p, x_vals,
    # y_modes,
    # yerror = (y_err_lower_minmax, y_err_upper_minmax),
    # color = :blue,
    # msc = :red,
    # markersize = 3,
    # label = false)

    # hline!(p, [round(max_y_mode; digits=2)], color = :blue, linestyle = :dash, label = "max value")
    # max_y_index = argmax(y_modes)  # Get the index where max_y occurs
    # # max_x_at_max_y = x_vals[max_y_index]  # Get the corresponding x-value
    # annotate!(p, 1.4, max_y + 0.02, Plots.text("$(round(max_y_mode; digits=2))", :center, 7, :blue))
end

function create_and_save_plot(dir, filename, f, data...)
    if !isnothing(filename)
        p = f(data...)
        mkpath("../" * dir)
        savefig(p, "../" * dir * "/" * filename)
        println("Plot saved as $(dir * "/" * filename)")
    end
end

function import_results(file::String)::SortedDict{Int, Vector{Float64}}
    local results::SortedDict{Int, Vector{Float64}}
    open("../benchmark_results/$file") do io
        parsed_data = JSON.parse(io)
        results = SortedDict(parse(Int, k) => v for (k, v) in parsed_data)
    end
    results
end


function construct_histogram(data::Vector{TrialEntry}, y_func; bins = 100, xlabel = "Value", ylabel = "Frequency", title = "Histogram", p = nothing)
    bin_edges = range(45, 100; length = bins + 1)
    y_values = [y_func(entry) for entry in data]

    yticks_vals = 0:10:100

    p = histogram(y_values,
    bins = bin_edges,
    xlabel = xlabel,
    ylabel = ylabel,
    title = title,
    xlabelfontsize = 12,
    ylabelfontsize = 12,
    titlefontsize = 12,
    legend = false,
    grid = true,
    color = :red,
    alpha = 0.7,
    xlims = (45, 91),
    ylims = (0, 95),
    yticks = yticks_vals)


    return p
end
