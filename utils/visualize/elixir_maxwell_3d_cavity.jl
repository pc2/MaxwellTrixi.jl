# Figure or GLMakie video for examples/dgmulti_3d/elixir_maxwell_3d_cavity.jl.
using Trixi, MaxwellTrixi
using GLMakie, CairoMakie

if !isdefined(@__MODULE__, :MaxwellVisuals)
    include(joinpath(@__DIR__, "common.jl"))
end
using .MaxwellVisuals

video = "--video" in ARGS
frames = 241
framerate = 30
tspan = (0.0, 2.0)
frame_times = video ? collect(range(tspan..., length = frames)) : [0.25]
output_directory = joinpath(pkgdir(MaxwellTrixi), "docs", video ? "videos" : "figures")
output_name = "cavity_mode"
simulation_overrides = (;)

video ? GLMakie.activate!() : CairoMakie.activate!()
elixir = pkgdir(MaxwellTrixi, "examples", "dgmulti_3d", "elixir_maxwell_3d_cavity.jl")
variables = ("Ez", "Hx")
result = sample_elixir(elixir, frame_times; variables, slice = :xy, point = (0.5, 0.5, 0.5),
                       overrides = simulation_overrides)
results = [result]

figure = Figure(size = (900, 400))
plot_time = Observable(first(result.frames).t)
panels = Any[]
indices = [(frame_index, variable_index)
           for frame_index in (video ? (1,) : eachindex(result.frames))
           for variable_index in eachindex(variables)]
for (column, (frame_index, variable_index)) in enumerate(indices)
    panel = field_panel!(figure[1, column], result, variable_index;
                         variable = variables[variable_index], frame_index,
                         time = video ? plot_time : nothing, ylabel = "y", plot_mesh = true,
                         colorrange = nothing)
    push!(panels, panel)
    Colorbar(figure[2, column], panel.plot; vertical = false)
end
probe_plots = nothing
plot_view = (; figure, panels, probe_plots, time = plot_time)
visualization = write_visualization(plot_view, results; video, framerate,
                                    output_directory, output_name)
