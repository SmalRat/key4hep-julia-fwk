function get_machine_info(machine_info_filename::String)::Dict
    machine_info = Dict()
    if isfile(machine_info_filename)
        open(machine_info_filename, "r") do io
            machine_info = JSON.parse(io)
        end
        @warn "Retrieved machine info from file: $machine_info_filename."
    else
        @warn "Machine info file not found. Skipping machine info."
    end
    machine_info
end
