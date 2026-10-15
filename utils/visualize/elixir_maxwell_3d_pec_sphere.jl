# Figure or GLMakie video for examples/dgmulti_3d/elixir_maxwell_3d_pec_sphere.jl.
using Trixi, TrixiMaxwell
using GLMakie, CairoMakie

if !isdefined(@__MODULE__, :MaxwellVisuals)
    include(joinpath(@__DIR__, "common.jl"))
end
using .MaxwellVisuals

video = "--video" in ARGS
frames = 241
framerate = 30
tspan = (0.0, 11.0)
frame_times = video ? collect(range(tspan..., length = frames)) : [3.5, 5.5]
output_directory = joinpath(pkgdir(TrixiMaxwell), "docs", video ? "videos" : "figures")
output_name = "pec_sphere"
simulation_overrides = (;)

video ? GLMakie.activate!() : CairoMakie.activate!()
elixir = pkgdir(TrixiMaxwell, "examples", "dgmulti_3d", "elixir_maxwell_3d_pec_sphere.jl")
variables = ("Ex",)
result = sample_elixir(elixir, frame_times; variables, overrides = simulation_overrides)
results = [result]

figure = Figure(size = video ? (900, 700) : (1000, 480))
plot_time = Observable(first(result.frames).t)
panels = Any[]
radius = 1.0
angles = range(0.0, 2 * pi, length = 361)
indices = [(frame_index, variable_index)
           for frame_index in (video ? (1,) : eachindex(result.frames))
           for variable_index in eachindex(variables)]
for (column, (frame_index, variable_index)) in enumerate(indices)
    panel = field_panel!(figure[1, column], result, variable_index;
                         variable = variables[variable_index], frame_index,
                         time = video ? plot_time : nothing)
    lines!(panel.axis, radius .* cos.(angles), radius .* sin.(angles);
           color = :black, linewidth = 1.5)
    lines!(panel.axis, [-1.5, 1.5, 1.5, -1.5, -1.5],
           [-1.5, -1.5, 1.5, 1.5, -1.5]; color = :black, linestyle = :dash)
    push!(panels, panel)
end
Colorbar(figure[1, length(panels) + 1], first(panels).plot; label = first(variables))
probe_plots = nothing
Label(figure[2, 1:(length(panels) + 1)],
      "Inside dashed box: incident + scattered; outside: scattered only.")
plot_view = (; figure, panels, probe_plots, time = plot_time)
visualization = write_visualization(plot_view, results; video, framerate,
                                    output_directory, output_name)
