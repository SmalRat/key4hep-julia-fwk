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
