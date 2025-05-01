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

function Base.show(io::IO, bp::BenchmarkParameters)
    println(io, "BenchmarkParameters(")
    println(io, "  threads_num     = ", bp.threads_num)
    println(io, "  pin_threads     = ", bp.pin_threads)
    println(io, "  samples         = ", bp.samples)
    println(io, "  evals           = ", bp.evals)
    println(io, "  timeout         = ", bp.timeout)
    println(io, "  results_filename= ", bp.results_filename)
    print(io, ")")
end
