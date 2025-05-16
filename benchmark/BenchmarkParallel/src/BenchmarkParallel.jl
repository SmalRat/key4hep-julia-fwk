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


export BenchmarkParallelUtils
export ExperimentParametersGenerator, SimpleEPG, launcher

end # module BenchmarkParallel
