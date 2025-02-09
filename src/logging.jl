using Dagger
using Logging, LoggingExtras

function enable_logging!()
    Dagger.enable_logging!(tasknames = true,
                           taskfuncnames = true,
                           taskdeps = true,
                           taskargs = true,
                           taskargmoves = true,
                           taskresult = true,
                           taskuidtotid = true,
                           tasktochunk = true)
end

function disable_logging!()
    Dagger.disable_logging!()
end

function fetch_logs!()
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
