abstract type AbstractExperiment end

"Interface function"
function do_work(x::AbstractExperiment)
    error("do_work not implemented for $(typeof(x))")
end

function setup_experiment(x::AbstractExperiment)
    println("Setting up experiment for $(typeof(x))")
end

function run_experiment(x::AbstractExperiment)
    println("Running experiment for $(typeof(x))")
    do_work(x)
end

function teardown_experiment(x::AbstractExperiment)
    println("Tearing down experiment for $(typeof(x))")
end

function get_version(x::AbstractExperiment)
    return "0.1"
end

get_experiment_parameters(x::AbstractExperiment) = Dict()

export AbstractExperiment, do_work, setup_experiment, run_experiment, teardown_experiment, get_version, get_experiment_parameters

