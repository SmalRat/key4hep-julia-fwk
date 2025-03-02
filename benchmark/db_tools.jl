const DB_DIR = "benchmark_results"


function load_db_file(filename::AbstractString)
    endswith(filename, ".json") || badext(filename)

    mkpath(DB_DIR)
    filename = joinpath(DB_DIR, filename)
    println("Loading data from $filename")

    existing_data = if isfile(filename)
        try
            open(filename, "r") do io
                JSON.parse(io)
            end
        catch
            []
        end
    else
        []
    end
    return existing_data
end


function trial_to_dict(t::BenchmarkTools.Trial)
    # Generate new dict from BenchmarkTools.Trial object
    buffer = IOBuffer()
    BenchmarkTools.save(buffer, t)
    return JSON.parse(String(take!(buffer)))
end


function append_save(filename::AbstractString, t::BenchmarkTools.Trial, parameters::Dict)
    existing_data = load_db_file(filename)
    new_entry = trial_to_dict(t)
    println("Appending new entry to $new_entry")

    new_entry = push!(new_entry, parameters)

    push!(existing_data, new_entry)

    open(filename, "w") do io
        JSON.print(io, existing_data, 2)
    end
end
