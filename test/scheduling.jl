using FrameworkDemo
using Test
using Dagger
using Graphs
using MetaGraphs
using Logging

function get_alg_timeline(logs::Dict)
    timeline = Dict{Int, Any}()
    Dagger.logs_event_pairs(logs) do w, start_idx, finish_idx
        category = logs[w][:core][start_idx].category
        if category == :compute
            tid = logs[w][:id][start_idx].thunk_id
            t_start = logs[w][:core][start_idx].timestamp
            t_stop = logs[w][:core][finish_idx].timestamp
            timeline[tid] = (start = t_start, stop = t_stop)
        end
    end
    return timeline
end

function get_alg_deps(logs::Dict)
    task_deps = Dict{Int, Set{Int}}()
    for w in keys(logs)
        for idx in 1:length(logs[w][:core])
            category = logs[w][:core][idx].category
            kind = logs[w][:core][idx].kind
            if category == :add_thunk && kind == :start
                (tid, deps) = logs[w][:taskdeps][idx]
                if isa(deps, Vector{Int}) && !isempty(deps)
                    task_deps[tid] = Set{Int}(deps)
                end
            end
        end
    end
    return task_deps
end

@testset "Scheduling" begin
    path = joinpath(pkgdir(FrameworkDemo), "data/demo/datadeps/df.graphml")
    graph = FrameworkDemo.parse_graphml(path)
    ilength(x) = sum(_ -> 1, x) # no standard length for MetaGraphs.filter_vertices iterator
    algorithms_count = ilength(MetaGraphs.filter_vertices(graph, :type, "Algorithm"))
    set_indexing_prop!(graph, :node_id)
    is_fast = "no-fast" ∉ ARGS
    coefficients = FrameworkDemo.calibrate_crunch(; fast = is_fast)

    df = FrameworkDemo.mockup_dataflow(graph)
    event = FrameworkDemo.Event(df)

    Dagger.enable_logging!(tasknames = true, taskdeps = true)
    _ = FrameworkDemo.fetch_trace!() # flush

    tasks = FrameworkDemo.schedule_graph!(event, coefficients)
    wait.(tasks)

    trace = FrameworkDemo.fetch_trace!()
    FrameworkDemo.disable_tracing!()
    @test !isnothing(trace)

    task_to_tid = lock(Dagger.Sch.EAGER_ID_MAP) do id_map
        return deepcopy(id_map)
    end

    function get_tid(node_id::String)::Int
        task = FrameworkDemo.get_result(event, graph[node_id, :node_id])
        return task_to_tid[task.uid]
    end

    @testset "Timeline" begin
        timeline = get_alg_timeline(trace)
        @test length(timeline) == algorithms_count

        get_time = (node_id) -> timeline[get_tid(node_id)]

        @test get_time("ProducerA").stop < get_time("TransformerAB").start
        @test get_time("ProducerBC").stop < get_time("TransformerAB").start
        @test get_time("ProducerBC").stop < get_time("ConsumerBC").start
        @test get_time("ProducerBC").stop < get_time("TransformerC").start
        @test get_time("ProducerBC").stop < get_time("ConsumerCD").start
        @test get_time("TransformerAB").stop < get_time("ConsumerE").start
        @test get_time("TransformerAB").stop < get_time("ConsumerCD").start
    end

    @testset "Dependencies" begin
        deps = get_alg_deps(trace)
        get_deps = node_id -> deps[get_tid(node_id)]

        @test get_tid("ProducerA") ∈ get_deps("TransformerAB")
        @test get_tid("ProducerBC") ∈ get_deps("TransformerAB")
        @test get_tid("ProducerBC") ∈ get_deps("ConsumerBC")
        @test get_tid("ProducerBC") ∈ get_deps("TransformerC")
        @test get_tid("ProducerBC") ∈ get_deps("ConsumerCD")
        @test get_tid("TransformerAB") ∈ get_deps("ConsumerE")
        @test get_tid("TransformerAB") ∈ get_deps("ConsumerCD")
    end

    @testset "Pipeline" begin
        event_count = 5
        data_flow = FrameworkDemo.mockup_dataflow(graph)

        test_logger = TestLogger()
        with_logger(test_logger) do
            FrameworkDemo.run_pipeline(data_flow;
                                       max_concurrent = 3,
                                       event_count = event_count,
                                       crunch_coefficients = coefficients)
        end
        @testset "Start message" begin
            messages = for i in 1:event_count
                @test any(record -> record.message == FrameworkDemo.dispatch_begin_msg(i),
                          test_logger.logs)
            end
        end
        @testset "Finish message" begin
            messages = for i in 1:event_count
                @test any(record -> record.message == FrameworkDemo.dispatch_end_msg(i),
                          test_logger.logs)
            end
        end
    end
end
