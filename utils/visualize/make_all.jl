# Run the scenario files themselves, so single and batch output follow one path.
using Trixi, TrixiMaxwell
include("common.jl")

scripts = sort(filter(path -> startswith(basename(path), "elixir_maxwell_") &&
                          endswith(path, ".jl"),
                      [joinpath(directory, file)
                       for (directory, _, files) in walkdir(@__DIR__)
                       for file in files]))
for script in scripts
    trixi_include(script; video = "--video" in ARGS)
    GC.gc()
end
