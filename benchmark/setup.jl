using JSON
using ArgParse

function get_cpu_info()
    cpu_info = Dict()

    if Sys.KERNEL == :Linux
        cpu_model = readchomp(pipeline(`lscpu`,`grep "Model name"`))
        threads_per_core = readchomp(pipeline(`lscpu`, `grep "^Thread(s) per core:"`))
        cores_per_socket = readchomp(pipeline(`lscpu`, `grep "^Core(s) per socket:"`))
        num_sockets = readchomp(pipeline(`lscpu`, `grep "Socket(s)"`))

        cpu_info["cpu_model"] = cpu_model
        cpu_info["threads_per_core"] = threads_per_core
        cpu_info["cores_per_socket"] = cores_per_socket
        cpu_info["num_sockets"] = num_sockets
    elseif Sys.KERNEL == :Windows
        @warn "Windows detected, functionality was not tested!"
        cpu_model = readchomp(`wmic cpu get caption`)
        num_cores = readchomp(`wmic cpu get numberofcores`)
        num_sockets = readchomp(`wmic cpu get socketdesignation`)

        cpu_info["cpu_model"] = cpu_model
        cpu_info["num_cores"] = num_cores
        cpu_info["num_sockets"] = num_sockets
    else
        @error "Unsupported OS: $(Sys.KERNEL). Fill hardware info manually."
    end

    return cpu_info
end

function get_os_info()
    os_info = Dict()

    if Sys.KERNEL == :Linux
        os_name = readchomp(`uname -s`)
        os_version = readchomp(`uname -r`)

        os_info["os_name"] = os_name
        os_info["os_version"] = os_version
    elseif Sys.KERNEL == :Windows
        @warn "Windows detected, functionality was not tested!"
        os_name = readchomp(`ver`)
        os_version = readchomp(`wmic os get version`)

        os_info["os_name"] = os_name
        os_info["os_version"] = os_version
    else
        @error "Unsupported OS: $(Sys.KERNEL). Fill OS info manually."
    end

    return os_info
end

function get_boost_info()
    boost_info = Dict{String, Any}("boost_enabled" => "unknown")

    if Sys.KERNEL == :Linux
        try
            flag = readchomp(`cat /sys/devices/system/cpu/cpufreq/boost`)
            if flag == "1"
                boost_info["boost_enabled"] = true
            else
                boost_info["boost_enabled"] = false
            end
        catch
            @error "Error reading boost info. Fill boost info manually."
        end
    else
        @error "Unsupported OS: $(Sys.KERNEL). Fill boost info manually."
    end

    return boost_info
end

function create_machine_info_json(machine_id::String)
    machine_info = Dict()

    machine_info["machine_id"] = machine_id
    machine_info["hardware_info"] = get_cpu_info()
    machine_info["os_info"] = get_os_info()
    machine_info["boost_info"] = get_boost_info()

    open("machine_info.json", "w") do f
        JSON.print(f, machine_info, 2)
    end

    println("Machine info saved to machine_info.json. Check the file for details and correction before benchmarking.")
end

function parse_args(raw_args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--machine-id"
        help = "Machine id"
        arg_type = String
        required = true
    end

    return ArgParse.parse_args(raw_args, s)
end

function (@main)(raw_args)
    args = parse_args(raw_args)

    machine_id::String = args["machine-id"]
    create_machine_info_json(machine_id)
end
