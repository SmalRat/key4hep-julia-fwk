using JSON

base_json = JSON.parsefile("template_experiments_set.json")
base_experiment = base_json[1]["experiments"][1]

# Function to generate the range of max_concurrent_events for a given thread_count
function max_concurrent_range(thread_count)
    if thread_count == 1
        return 1:8
    elseif thread_count == 2
        return 1:10
    elseif 3 ≤ thread_count ≤ 9
        return 1:14
    elseif 10 ≤ thread_count ≤ 16
        return 1:16
    elseif 17 ≤ thread_count ≤ 20
        return 1:20
    else
        return Int[]
    end
end

function generate_experiments()
    # Generate all experiments
    experiments = []

    id_counter = 1

    for thread_count in 1:20
        for max_concurrent_events in max_concurrent_range(thread_count)
            push!(experiments, Dict(
                "id" => string(id_counter),
                "data_flow" => base_experiment["data_flow"],
                "event_count" => base_experiment["event_count"],
                "max_concurrent_events" => max_concurrent_events,
                "threads_num" => thread_count,
                "fast" => base_experiment["fast"]
            ))
            id_counter += 1
        end
    end

    experiments
end

experiments = generate_experiments()

output = [
    Dict(
        "name" => base_json[1]["name"],
        "description" => base_json[1]["description"],
        "experiments" => experiments
    )
]

open("generated_experiment_sets.json", "w") do f
    JSON.print(f, output, 4)
end

println("Generated $(length(experiments)) experiments.")
