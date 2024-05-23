using Colors
using DaggerWebDash
using Distributed
using GraphViz

addprocs(10)

@everywhere begin
    using Dagger
    using TimespanLogging
    using DaggerWebDash

    function taskA()
        println("In taskA, worker id: " * string(myid()))

        for _ in 1:1
            sleep(1)
            println("Slept for a 2 seconds in taskA")
        end
        
        return "Executed A"
    end
    
    function taskB(x)
        println("In taskB, worker id: " * string(myid()))

        for _ in 1:1
            sleep(2)
            println("Slept for a 2 seconds in taskB")
        end
        
        return "Executed B after " * x
    end
    
    function taskC(x)
        println("In taskC, worker id: " * string(myid()))

        for _ in 1:1
            sleep(1)
            println("Slept for a 2 seconds in taskC")
        end
        
        return "Executed C after " * x
    end
    
    function taskD(x, y)
        println("In taskD, worker id: " * string(myid()))

        for _ in 1:1
            sleep(1)
            println("Slept for a 2 seconds in taskD")
        end
        
        return "Executed D after " * x * " and " * y
    end

    function taskE(x, y, z)
        println("In taskE, worker id: " * string(myid()))

        for _ in 1:1
            sleep(1)
            println("Slept for a 2 seconds in taskE")
        end
        
        return "Executed E after " * x * " and " * y * " and " * z
    end

    function mock_func()
        sleep(1)
        return
    end

    function print_func(x...)
        sleep(x[1])
        println("Finished")
        return length(x)
    end
end

function task_setup() 
    a = Dagger.delayed(taskA)()
    b = Dagger.delayed(taskB)(a)
    c = Dagger.delayed(taskC)(a)
    d = Dagger.delayed(taskD)(b, c)
    e = Dagger.delayed(taskE)(b, c, d)

    return e
end

function graph_viz_setup_logs() 
    ctx = Dagger.Sch.eager_context()
    log = TimespanLogging.LocalEventLog()
    ctx.log_sink = log
    ctx.log_file = "./graphs_scheduling/results/logs/out.svg"

    return
end

function get_viz_logs() 
    ctx = Dagger.Sch.eager_context()
    logs = TimespanLogging.get_logs!(ctx.log_sink)
    # plan = Dagger.show_plan(logs)

    return 
end

function configure_webdash_multievent()
    ctx = Dagger.Sch.eager_context()
    ml = Dagger.TimespanLogging.MultiEventLog()

    TimespanLogging = Dagger.TimespanLogging
    ## Add some logging events of interest

    ml[:core] = TimespanLogging.Events.CoreMetrics()
    ml[:id] = TimespanLogging.Events.IDMetrics()
    ml[:timeline] = TimespanLogging.Events.TimelineMetrics()
    # ...

    # (Optional) Enable profile flamegraph generation with ProfileSVG
    ml[:profile] = DaggerWebDash.ProfileMetrics()
    ctx.profile = true

    # Create a LogWindow; necessary for real-time event updates
    lw = TimespanLogging.Events.LogWindow(20*10^9, :core)
    ml.aggregators[:logwindow] = lw

    # Create the D3Renderer server on port 8080
    d3r = DaggerWebDash.D3Renderer(8080)

    ## Add some plots! Rendered top-down in order

    # Show an overview of all generated events as a Gantt chart
    push!(d3r, DaggerWebDash.GanttPlot(:core, :id, :esat, :psat; title="Overview"))

    # Show various numerical events as line plots over time
    push!(d3r, DaggerWebDash.LinePlot(:core, :wsat, "Worker Saturation", "Running Tasks"))
    push!(d3r, DaggerWebDash.LinePlot(:core, :loadavg, "CPU Load Average", "Average Running Threads"))
    push!(d3r, DaggerWebDash.LinePlot(:core, :bytes, "Allocated Bytes", "Bytes"))
    push!(d3r, DaggerWebDash.LinePlot(:core, :mem, "Available Memory", "% Free"))

    # Show a graph rendering of compute tasks and data movement between them
    # Note: Profile events are ignored if absent from the log
    push!(d3r, DaggerWebDash.GraphPlot(:core, :id, :timeline, :profile, "DAG"))

    # TODO: Not yet functional
    #push!(d3r, DaggerWebDash.ProfileViewer(:core, :profile, "Profile Viewer"))
    # Add the D3Renderer as a consumer of special events generated by LogWindow
    push!(lw.creation_handlers, d3r)
    push!(lw.deletion_handlers, d3r)

    # D3Renderer is also an aggregator
    ml.aggregators[:d3r] = d3r

    ctx.log_sink = ml
end

function do_DAGs_task(graphs_number, nodes_in_graph=3)
    # Execute the task graph
    parallel_graphs_results = []
    lock1 = ReentrantLock()
    
    for j in 1:graphs_number
        graph_result = []
        for i in 1:nodes_in_graph
            if (i > 1)
                result = Dagger.@spawn print_func(graph_result...)
            else
                result = Dagger.@spawn print_func(i)
            end
            
            lock(lock1)
            push!(graph_result, result)
            unlock(lock1)
        end
        push!(parallel_graphs_results, graph_result)
    end

    for (i, graph) in enumerate(parallel_graphs_results)
        println("Graph $i")
        for res in graph
            println(fetch(res))
        end
    end

    # res = Dagger.delayed(finish_func)(parallel_graphs...)
    res = Dagger.delayed(mock_func)()
    ctx = Dagger.Sch.eager_context()
    a = collect(ctx, res)
end


# configure_webdash_multievent()
# sleep(10)

graph_viz_setup_logs()
do_DAGs_task(5)
get_viz_logs()
