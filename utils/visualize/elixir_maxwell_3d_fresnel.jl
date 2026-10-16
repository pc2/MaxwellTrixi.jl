# Figure or GLMakie video for examples/dgmulti_3d/elixir_maxwell_3d_fresnel.jl.
using Trixi, MaxwellTrixi
using GLMakie, CairoMakie

if !isdefined(@__MODULE__, :MaxwellVisuals)
    include(joinpath(@__DIR__, "common.jl"))
end
using .MaxwellVisuals

video = "--video" in ARGS
frames = 241
framerate = 30
tspan = (0.0, 1.6)
frame_times = video ? collect(range(tspan..., length = frames)) : [0.2, 0.5, 0.8]
output_directory = joinpath(pkgdir(MaxwellTrixi), "docs", video ? "videos" : "figures")
output_name = "fresnel"
simulation_overrides = (;)

video ? GLMakie.activate!() : CairoMakie.activate!()
elixir = pkgdir(MaxwellTrixi, "examples", "dgmulti_3d", "elixir_maxwell_3d_fresnel.jl")
variables = ("Ey",)
result = sample_elixir(elixir, frame_times; variables, point = (0.0, 0.25, 0.0),
                       metadata = (:epsilon_left, :epsilon_right),
                       overrides = simulation_overrides)
results = [result]

figure = Figure(size = video ? (900, 320) : (1200, 260))
plot_time = Observable(first(result.frames).t)
panels = Any[]
indices = [(frame_index, variable_index)
           for frame_index in (video ? (1,) : eachindex(result.frames))
           for variable_index in eachindex(variables)]
for (column, (frame_index, variable_index)) in enumerate(indices)
    panel = field_panel!(figure[1, column], result, variable_index;
                         variable = variables[variable_index], frame_index,
                         time = video ? plot_time : nothing)
    vlines!(panel.axis, [0.0]; color = :black, linestyle = :dash)
    text!(panel.axis, -0.9, 0.42; text = "epsilon = $(result.metadata[:epsilon_left])",
          fontsize = 14)
    text!(panel.axis, 0.3, 0.42; text = "epsilon = $(result.metadata[:epsilon_right])",
          fontsize = 14)
    push!(panels, panel)
end
Colorbar(figure[1, length(panels) + 1], first(panels).plot; label = first(variables))
probe_plots = nothing
plot_view = (; figure, panels, probe_plots, time = plot_time)
visualization = write_visualization(plot_view, results; video, framerate,
                                    output_directory, output_name)
