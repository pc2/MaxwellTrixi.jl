# Figure or GLMakie video for examples/dgmulti_3d/elixir_maxwell_3d_dipole.jl.
using Trixi, TrixiMaxwell
using GLMakie, CairoMakie
using StaticArrays: SVector

if !isdefined(@__MODULE__, :MaxwellVisuals)
    include(joinpath(@__DIR__, "common.jl"))
end
using .MaxwellVisuals

video = "--video" in ARGS
frames = 241
framerate = 30
tspan = (0.0, 4.0)
frame_times = video ? collect(range(tspan..., length = frames)) : [2.0]
output_directory = joinpath(pkgdir(TrixiMaxwell), "docs", video ? "videos" : "figures")
output_name = "dipole"
simulation_overrides = (;)

video ? GLMakie.activate!() : CairoMakie.activate!()
elixir = pkgdir(TrixiMaxwell, "examples", "dgmulti_3d", "elixir_maxwell_3d_dipole.jl")
variables = ("Ez",)
xs = range(0.3, 0.95, length = 60)
probe = (; xs, points = [SVector(x, 0.0, 0.0) for x in xs],
         variable = "Ez", reference = :dipole_field)
result = sample_elixir(elixir, frame_times; variables, probe,
                       overrides = simulation_overrides)
results = [result]

figure = Figure(size = (1000, 420))
plot_time = Observable(first(result.frames).t)
panels = Any[]
indices = [(frame_index, variable_index)
           for frame_index in (video ? (1,) : eachindex(result.frames))
           for variable_index in eachindex(variables)]
for (column, (frame_index, variable_index)) in enumerate(indices)
    panel = field_panel!(figure[1, column], result, variable_index;
                         variable = variables[variable_index], frame_index,
                         time = video ? plot_time : nothing, plot_mesh = true,
                         colorrange = (-1.5f0, 1.5f0))
    push!(panels, panel)
end
Colorbar(figure[1, length(panels) + 1], first(panels).plot; label = first(variables))

probe_data = result.frames[video ? 1 : end].probe
probe_axis = Axis(figure[1, length(panels) + 2]; title = "Ez along the x axis",
                  titlealign = :left, xlabel = "x", ylabel = "Ez")
limit = max(1e-6,
            maximum(max(maximum(abs, f.probe.exact),
                        maximum(abs, f.probe.numerical)) for f in result.frames))
limits!(probe_axis, extrema(probe_data.xs)..., -1.05 * limit, 1.05 * limit)
exact = lines!(probe_axis, probe_data.xs, probe_data.exact; color = :black, label = "exact")
numerical = scatter!(probe_axis, probe_data.xs, probe_data.numerical;
                     color = :red, markersize = 6, label = "DG")
axislegend(probe_axis)
probe_plots = (; exact, numerical)
plot_view = (; figure, panels, probe_plots, time = plot_time)
visualization = write_visualization(plot_view, results; video, framerate,
                                    output_directory, output_name)
