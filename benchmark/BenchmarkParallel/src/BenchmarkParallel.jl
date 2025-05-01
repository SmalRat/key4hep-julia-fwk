module BenchmarkParallel

using UUIDs
using JSON
using BenchmarkPlots
using StatsPlots
using Logging
using BenchmarkTools
using ThreadPinning
using SysInfo

include("AbstractExperiments.jl")
include("benchmark_utils/benchmark_utils.jl")
using .BenchmarkParallelUtils
include("launch.jl")
# include("worker.jl")


# export custom_exitcode_on_error
# export BenchmarkParameters, BenchmarkMetadata, AllParams, BenchmarkResults
export BenchmarkParallelUtils
export ExperimentParametersGenerator, SimpleEPG, launcher

end # module BenchmarkParallel
