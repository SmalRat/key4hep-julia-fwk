using UUIDs

mutable struct BenchmarkMetadata
    start_time::String
    end_time::String
    UUID::String
    benchmark_version::String

    BenchmarkMetadata(version::String) = new("", "", string(UUIDs.uuid4()), version)
end

function get_benchmark_version(b_metadata::BenchmarkMetadata)
    return b_metadata.benchmark_version
end

register_start_time(metadata::BenchmarkMetadata) = metadata.start_time = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
register_end_time(metadata::BenchmarkMetadata) = metadata.end_time = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
