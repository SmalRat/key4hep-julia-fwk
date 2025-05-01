using ArgParse
using Serialization
using Dates

# using .AbstractExperiments

abstract type ExperimentParametersGenerator end

struct SimpleEPG <:ExperimentParametersGenerator
    experiment::AbstractExperiment
    parameters::BenchmarkParameters
    threads_min_num::Int
    threads_max_num::Int
end

function Base.iterate(epg::SimpleEPG, state = epg.threads_min_num)
    if state > epg.threads_max_num
        return nothing
    else
        epg.parameters.threads_num = state
        return ((epg.experiment, epg.parameters), state + 1)
    end
end

Base.IteratorSize(::Type{SimpleEPG}) = Base.HasLength()
Base.length(epg::SimpleEPG) = epg.threads_max_num - epg.threads_min_num + 1


function launcher(experiment::AbstractExperiment, parameters::BenchmarkParameters, implementation::String, errors_log_filename::String, relaunch_on_error::Bool)
    implementation_source = first(methods(typeof(experiment))).file
    # println("Implementation source: $implementation_source")
    ENV["JULIA_PARALLEL_TEST_IMPL_M"] = implementation_source
    t = parameters.threads_num

    open(errors_log_filename, "a") do f_errors_log
        write(f_errors_log, "\n" * Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS" * "\n\n"))
        flush(f_errors_log)

        while (true)
            worker_script_path = joinpath(dirname(@__FILE__), "worker.jl")
            # worker_script_path = "test1.jl"
            worker_cmd = Cmd(`julia --threads=$t --project=. $worker_script_path`) # TODO Env var
            worker_in = Pipe()
            proc = run(pipeline(ignorestatus(worker_cmd), stderr=f_errors_log, stdout=stdout, stdin=worker_in), wait=false)
            serialize(worker_in, experiment)
            serialize(worker_in, parameters)
            flush(worker_in)
            close(worker_in.in)
            wait(proc)

            exit_code = proc.exitcode

            if (exit_code == 0)
                println("Worker with $t threads finished successfully.")
                break
            elseif (exit_code != 43 && exit_code != 44)
                println("Worker with $t threads failed with exit code: $exit_code. Errors output saved to file $errors_log_filename.")
                println("Exiting...")
                break
            else
                println("Worker with $t threads failed with exit code: $exit_code. Errors output saved to file $errors_log_filename.")
                !relaunch_on_error && (println("Exiting..."); break)
                println("Relaunching worker process with $t threads...")
            end
        end
    end
end
