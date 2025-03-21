using Dagger
using Logging, LoggingExtras

function enable_tracing!()
    Dagger.enable_logging!(tasknames = true,
                           taskfuncnames = true,
                           taskdeps = true,
                           taskargs = true,
                           taskargmoves = true,
                           taskresult = true,
                           taskuidtotid = true,
                           tasktochunk = true)
end

function disable_tracing!()
    Dagger.disable_logging!()
end

function fetch_trace!()
    return Dagger.fetch_logs!()
end

function dispatch_begin_msg(index)
    "Dispatcher: scheduled graph $index"
end

function dispatch_end_msg(index)
    "Dispatcher: finished graph $index"
end

function all_tasks_finished_msg(graph_id)
    "Graph $graph_id: all tasks in the graph finished!"
end

function graph_finish_notified_msg(graph_id)
    "Graph $graph_id: notified!"
end

function redirect_logs_to_file(logfile)
    logger = FileLogger(logfile)
    global_logger(logger)
end

function disable_all_logs()
    global_logger(NullLogger())
end
