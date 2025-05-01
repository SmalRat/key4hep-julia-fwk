module BenchmarkParallelUtils

using BenchmarkParallel
using BenchmarkTools
using JSON
using ThreadPinning
using Dates
import SysInfo

include("macros.jl")
include("get_machine_info.jl")
include("thread_pinning.jl")
include("other.jl")

include("benchmark_parameters.jl")
include("benchmark_metadata.jl")
include("benchmark_results.jl")

struct AllParams
    experiment::AbstractExperiment
    benchmark_parameters::BenchmarkParameters
    machine_info::Dict
end

include("db_tools.jl")

export @custom_exitcode_on_error
export get_machine_info
export do_pin_threads
export BenchmarkParameters, BenchmarkMetadata, AllParams, BenchmarkResults
export get_benchmark_version
export register_start_time, register_end_time
export filter_db_helper, load_db_file_to_dicts, get_trial_entries_from_file, trial_append_to_db, filter_trial_entries
export TrialEntry


end
