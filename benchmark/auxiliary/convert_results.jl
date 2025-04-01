using ArgParse

include("../db_tools.jl")

function parse_args(raw_args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--db-filename"
        help = "Database filename to convert"
        arg_type = String
        required = true

        "--save-as"
        help = "Database filename to save to"
        arg_type = String
        required = true

        "--machine-info"
        help = "File with machine info"
        arg_type = String
        required = true
    end

    return ArgParse.parse_args(raw_args, s)
end

function (@main)(raw_args)
    args = parse_args(raw_args)

    db_filename::String = args["db-filename"]
    save_as::String = args["save-as"]
    machine_info_filename::String = args["machine-info"]

    db_entries = get_trial_entries_from_file(db_filename)

    machine_info = open(machine_info_filename, "r") do io
        JSON.parse(io)
    end

    for entry in db_entries
        entry.machine_info = machine_info
    end

    open(save_as, "w") do io
        JSON.print(io, db_entries, 2)
    end
end
