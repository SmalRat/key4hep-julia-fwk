using JSON

base_json = JSON.parsefile("template_experiments_set.json")
base_experiment = base_json[1]["experiments"][1]


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

function optimal_jobs_number(thread_count::Int)
    return convert(Int, ceil(thread_count / 2))
end

function generate_experiments_set_1()
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

function generate_experiments_set_2()
    experiments = []

    id_counter = 1

    for thread_count in (1, 8:8:128...)
        push!(experiments, Dict(
            "id" => string(id_counter),
            "data_flow" => base_experiment["data_flow"],
            "event_count" => base_experiment["event_count"],
            "max_concurrent_events" => optimal_jobs_number(thread_count),
            "threads_num" => thread_count,
            "fast" => base_experiment["fast"]
        ))
        id_counter += 1
    end

    experiments
end

function generate_experiments_set_3()
    experiments = []

    id_counter = 1

    for repetitions in 1:4
        for thread_count in 4:4:32
            push!(experiments, Dict(
                "id" => string(id_counter),
                "data_flow" => base_experiment["data_flow"],
                "event_count" => base_experiment["event_count"],
                "max_concurrent_events" => optimal_jobs_number(thread_count),
                "threads_num" => thread_count,
                "fast" => base_experiment["fast"]
            ))
            id_counter += 1
        end
    end

    experiments
end

function generate_experiments_set_4()
    experiments = []

    id_counter = 1

    for repetitions in 1:3
        for event_count in 10:10:200
            push!(experiments, Dict(
                "id" => string(id_counter),
                "data_flow" => base_experiment["data_flow"],
                "event_count" => event_count,
                "max_concurrent_events" => base_experiment["max_concurrent_events"],
                "threads_num" => base_experiment["threads_num"],
                "fast" => base_experiment["fast"]
            ))
            id_counter += 1
        end
    end

    experiments
end

experiments = generate_experiments_set_4()

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
