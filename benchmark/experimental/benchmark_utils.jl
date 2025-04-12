using BenchmarkTools
using JSON
using ThreadPinning
import SysInfo


function parse_kwargs_exprs(kwargs, d)
    for expr in kwargs
        if expr isa Expr && expr.head == :(=) && length(expr.args) == 2
            key = expr.args[1]
            value = expr.args[2]
            if key isa Symbol
                d[key] = value
            else
                error("Invalid key in keyword arguments: $key")
            end
        end
    end
end

macro custom_exitcode_on_error(ex, kwargs...)
    kwargs_dict = Dict{Symbol, Any}(:errmsg => nothing, :exitcode => 1)
    parse_kwargs_exprs(kwargs, kwargs_dict)

    errmsg = kwargs_dict[:errmsg]
    exitcode = kwargs_dict[:exitcode]

    return quote
        try
            $(esc(ex))
        catch
            if $errmsg !== nothing
                @error $errmsg
            end
            atexit(() -> exit($exitcode))
            rethrow()
        end
    end
end

function do_pin_threads()
    @info "Pinning Julia threads to CPU threads"
    cpu_threads::Vector{Int} = []
    i = 0
    n_numa_nodes = SysInfo.nnuma()

    for i in 1:n_numa_nodes
        cpu_threads = numa(i)
        if length(cpu_threads) != 0
            @info "Using NUMA node $(i-1)"
            break
        end
    end
    if length(cpu_threads) == 0
        throw(ErrorException("No NUMA node with CPUs found, exiting..."))
    end

    num_julia_threads = Threads.nthreads()
    if (num_julia_threads > length(cpu_threads))
        @warn "Warning: number of Julia threads ($num_julia_threads) is greater than allocated CPU threads ($cpu_threads). Oversubscribing."
        mult_factor = ceil(num_julia_threads / length(cpu_threads))
        cpu_threads = repeat(cpu_threads, Int(mult_factor))
    end
    pinthreads(cpu_threads) # Move to the CPU threads of the first numa node
    pinthreads(:current) # Pin threads to the current CPU threads
end

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

function save_violin_plot(t::BenchmarkTools.Trial)
    p = plot(t)
    dir = "violin_benchmark_plots"
    mkpath(dir)
    cur_file_name = "violin_plot.png"
    savefig(p, dir * "/" * cur_file_name)
    println("Violin benchmark plot saved as $cur_file_name")
end

mutable struct BenchmarkParameters
    threads_num::Int
    pin_threads::Bool

    samples::Int
    evals::Int
    timeout::Int

    results_filename::String

    function BenchmarkParameters(results_filename; threads_num=1, pin_threads=false, samples=25, evals=1, timeout=172800)
        return new(threads_num, pin_threads, samples, evals, timeout, results_filename)
    end
end

mutable struct BenchmarkMetadata
    start_time::String
    end_time::String
    UUID::String
    benchmark_version::String

    BenchmarkMetadata(version::String) = new("", "", string(UUIDs.uuid4()), version)
end

function get_benchmark_version(b_metadata::BenchmarkMetadata)
    return b_metadata.benchmark_version
end

function convert_(::Type{Dict}, benchmark_metadata::BenchmarkMetadata)
    metadata = Dict(
        "start_time" => benchmark_metadata.start_time,
        "end_time" => benchmark_metadata.end_time,
        "UUID" => benchmark_metadata.UUID
    )
    return metadata
end

register_start_time(metadata::BenchmarkMetadata) = metadata.start_time = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
register_end_time(metadata::BenchmarkMetadata) = metadata.end_time = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")

struct AllParams
    experiment::AbstractExperiment
    benchmark_parameters::BenchmarkParameters
    machine_info::Dict
end

mutable struct BenchmarkResults
    trial::BenchmarkTools.Trial
    warmup_time::Float64
end
