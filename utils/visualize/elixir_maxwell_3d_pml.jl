# Figure or GLMakie video for examples/dgmulti_3d/elixir_maxwell_3d_pml.jl.
using Trixi, TrixiMaxwell
using GLMakie, CairoMakie

if !isdefined(@__MODULE__, :MaxwellVisuals)
    include(joinpath(@__DIR__, "common.jl"))
end
using .MaxwellVisuals

video = "--video" in ARGS
frames = 241
framerate = 30
tspan = (0.0, 8.0)
frame_times = video ? collect(range(tspan..., length = frames)) : [4.0]
output_directory = joinpath(pkgdir(TrixiMaxwell), "docs", video ? "videos" : "figures")
output_name = "pml"
simulation_overrides = (;)

video ? GLMakie.activate!() : CairoMakie.activate!()
elixir = pkgdir(TrixiMaxwell, "examples", "dgmulti_3d", "elixir_maxwell_3d_pml.jl")
variables = ("Ez",)
dipole = HertzianDipole((0.0, 0.0, 0.0), (0.0, 0.0, 1.0),
                        0.1, GaussianPulse(0.4; delay = 1.4))
cases = ((; title = "uniaxial PML", overrides = (;)),
         (; title = "Silver-Mueller only",
          overrides = (; equations = MaxwellEquations3D(),
                       source_terms = dipole)))
results = [sample_elixir(elixir, frame_times; variables,
                         metadata = (:coordinates_max, :pml_thickness),
                         overrides = merge(case.overrides, simulation_overrides))
           for case in cases]

figure = Figure(size = (1000, 460))
plot_time = Observable(first(results[1].frames).t)
panels = Any[]
inner = results[1].metadata[:coordinates_max][1] - results[1].metadata[:pml_thickness]
indices = [(case_index, frame_index) for case_index in eachindex(results)
           for frame_index in (video ? (1,) : eachindex(results[case_index].frames))]
for (column, (case_index, frame_index)) in enumerate(indices)
    panel = field_panel!(figure[1, column], results[case_index], 1;
                         variable = "Ez", prefix = "$(cases[case_index].title), Ez",
                         case_index, frame_index, time = video ? plot_time : nothing,
                         colorrange = (-0.01f0, 0.01f0))
    lines!(panel.axis, [-inner, inner, inner, -inner, -inner],
           [-inner, -inner, inner, inner, -inner]; color = :black, linestyle = :dash)
    push!(panels, panel)
end
Colorbar(figure[1, length(panels) + 1], first(panels).plot; label = first(variables))
probe_plots = nothing
plot_view = (; figure, panels, probe_plots, time = plot_time)
visualization = write_visualization(plot_view, results; video, framerate,
                                    output_directory, output_name)
