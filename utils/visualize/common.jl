module MaxwellVisuals

using Trixi, TrixiMaxwell
using GLMakie, CairoMakie
using GeometryBasics
using StaticArrays: SVector

export sample_elixir, field_panel!, write_visualization, hexahedral_slice

# Convert live DG states into slice geometry, values and element outlines.
function tetrahedral_slice(u, semi, variable, config)
    ext = Base.get_extension(Trixi, :TrixiMakieExt)
    pds = PlotData2D(u, semi; slice = config.slice, point = config.point)[variable]
    geometry = ext.global_plotting_triangulation_makie(pds; set_z_coordinate_zero = true)
    values = Float32[getindex(p, 3)
                     for p in ext.global_plotting_triangulation_makie(pds).position]
    outlines = ext.convert_PlotData2D_to_mesh_Points(pds; set_z_coordinate_zero = true)
    return (; geometry, values, outlines)
end

# Cartesian DGSEM slice, retaining separate element traces and element outlines.
function hexahedral_slice(u_ode, semi, variable; slice = :xz,
                          point = (0.0, 0.0, 0.0), nvisnodes = nothing)
    mesh, equations, dg, cache = Trixi.mesh_equations_solver_cache(semi)
    u = Trixi.wrap_array(u_ode, semi)
    index = findfirst(==(variable), Trixi.varnames(cons2cons, equations))
    orientation_x, orientation_y, slice_dimension = slice == :xz ? (1, 3, 2) :
                                                    slice == :xy ? (1, 2, 3) : (2, 3, 1)
    plane = point[slice_dimension]
    nodes = dg.basis.nodes
    num_nodes = length(nodes)
    nvis = nvisnodes === nothing ? 2 * num_nodes : nvisnodes
    weights = Trixi.barycentric_weights(nodes)
    plotting = range(-1.0, 1.0, length = nvis)
    # built point by point: the lattice contains the element end points, which the
    # matrix routine cannot evaluate at
    to_plotting = reduce(vcat,
                         (Trixi.lagrange_interpolating_polynomials(x, nodes, weights)'
                          for x in plotting))
    node_coordinates = cache.elements.node_coordinates
    upper = maximum(view(node_coordinates, slice_dimension, :, :, :, :))

    vertices = zeros(0, 2)
    faces = zeros(Int, 0, 3)
    values = Float64[]
    outlines = Point2f[]
    for element in axes(node_coordinates, 5)
        lower = minimum(view(node_coordinates, slice_dimension, :, :, :, element))
        top = maximum(view(node_coordinates, slice_dimension, :, :, :, element))
        inside = lower <= plane < top || (plane == top && top == upper)
        inside || continue
        eta = 2 * (plane - lower) / (top - lower) - 1
        basis = Trixi.lagrange_interpolating_polynomials(eta, nodes, weights)
        data = Array(u[index, :, :, :, element])
        shape = ntuple(d -> d == slice_dimension ? num_nodes : 1, 3)
        sliced = dropdims(sum(reshape(basis, shape) .* data, dims = slice_dimension),
                          dims = slice_dimension)
        function axis(orientation)
            [node_coordinates[orientation,
                              ntuple(d -> d == orientation ? i : 1, 3)...,
                              element] for i in 1:num_nodes]
        end
        xs = to_plotting * axis(orientation_x)
        ys = to_plotting * axis(orientation_y)
        plotted = to_plotting * sliced * to_plotting'
        append!(outlines,
                Point2f.([(xs[1], ys[1]), (xs[end], ys[1]), (xs[end], ys[end]),
                             (xs[1], ys[end]), (xs[1], ys[1]), (NaN, NaN)]))
        offset = size(vertices, 1)
        vertices = vcat(vertices, [repeat(xs, nvis) repeat(ys, inner = nvis)])
        append!(values, vec(plotted))
        for j in 1:(nvis - 1), i in 1:(nvis - 1)
            a = offset + i + (j - 1) * nvis
            faces = vcat(faces, [a a+1 a+nvis; a+1 a+nvis+1 a+nvis])
        end
    end
    geometry = GeometryBasics.Mesh(Point2f.(Tuple.(eachrow(vertices))),
                                   GLTriangleFace.(Tuple.(eachrow(faces))))
    return (; geometry, values = Float32.(values), outlines)
end

function hexahedral_slice(u, semi, variable, config)
    return hexahedral_slice(u, semi, variable; slice = config.slice, point = config.point)
end

# Add a sampler to the existing callback set, preserving AMR and CFL callbacks.
# Forced stops sample live states instead of retaining full ODE snapshots, whose
# lengths and associated mesh can change during AMR.
function sampling_expression(ex, callback, times)
    ex isa Expr || return ex
    ex = Expr(ex.head, map(arg -> sampling_expression(arg, callback, times), ex.args)...)
    if ex.head === :call && ex.args[1] === :CallbackSet
        filter!(arg -> !(arg in (:save_vtk_callback, :save_solution_callback)), ex.args)
    elseif ex.head === :call && ex.args[1] === :solve
        parameters = only(filter(arg -> arg isa Expr && arg.head === :parameters,
                                 ex.args))
        filter!(arg -> !(arg isa Expr && arg.head === :kw && arg.args[1] === :tstops),
                parameters.args)
        push!(parameters.args, Expr(:kw, :tstops, times))
        for arg in parameters.args
            if arg isa Expr && arg.head === :kw && arg.args[1] === :callback
                arg.args[2] = Expr(:call, GlobalRef(Trixi, :CallbackSet),
                                   arg.args[2], callback)
            end
        end
    end
    return ex
end

elixir_var(mod, name) = Base.invokelatest(getglobal, mod, name)

function capture_frame(integrator, mod, config)
    u, semi, t = integrator.u, integrator.p, integrator.t
    fields = map(config.variables) do variable
        config.slice_field(u, semi, variable, config)
    end
    probe = nothing
    if config.probe !== nothing
        (; xs, points, variable, reference) = config.probe
        # Rebuild the evaluator on the current mesh, especially after AMR.
        numerical = PointEvaluator(points, semi)(u, semi)
        equations = Trixi.mesh_equations_solver_cache(semi)[2]
        index = findfirst(==(variable), Trixi.varnames(cons2cons, equations))
        exact_field = elixir_var(mod, reference)
        exact = [exact_field(x, t, equations)[index] for x in points]
        probe = (; xs, exact, numerical = getindex.(numerical, index))
    end
    return (; t = Float64(t), fields, probe)
end

mutable struct FrameSampler{Config}
    mod::Module
    config::Config
    times::Vector{Float64}
    frames::Vector{Any}
end

(sampler::FrameSampler)(u, t, integrator) = t in sampler.times

function (sampler::FrameSampler)(integrator)
    !isempty(sampler.frames) && last(sampler.frames).t == integrator.t && return nothing
    push!(sampler.frames,
          Base.invokelatest(capture_frame, integrator, sampler.mod,
                            sampler.config))
    return nothing
end

function Base.show(io::IO, cb::Trixi.DiscreteCallback{<:FrameSampler})
    print(io, "Visualization sampling (", length(cb.condition.times), " frames)")
end

function Base.show(io::IO, ::MIME"text/plain", cb::Trixi.DiscreteCallback{<:FrameSampler})
    show(io, cb)
end

"""
    sample_elixir(path, times; variables, slice=:xz, point=(0, 0, 0),
                  slice_field=tetrahedral_slice, probe=nothing, metadata=(), overrides=(;))

Sample a live simulation into independent slice frames. Mesh geometry and point
evaluators are rebuilt at every sampled time so AMR frames stay consistent.
"""
function sample_elixir(path, times; variables, slice = :xz, point = (0.0, 0.0, 0.0),
                       slice_field = tetrahedral_slice, probe = nothing,
                       metadata = (), overrides = (;))
    times = Float64.(collect(times))
    isempty(times) && throw(ArgumentError("At least one frame is required"))
    issorted(times) && allunique(times) ||
        throw(ArgumentError("Frame times must be strictly increasing"))
    config = (; variables, slice, point, slice_field, probe)
    mod = Module(gensym(:MaxwellVisualCase))
    frames = Any[]
    sampler = FrameSampler(mod, config, times, frames)
    initialize(cb, u, t, integrator) = t in times ? sampler(integrator) : nothing
    callback = Trixi.DiscreteCallback(sampler, sampler;
                                      initialize, save_positions = (false, false))
    kwargs = merge(overrides, (; tspan = (0.0, last(times))))
    trixi_include(ex -> sampling_expression(ex, callback, times), mod, path; kwargs...)
    [frame.t for frame in frames] ≈ times || error("Missing visualization frames")
    values = Dict(name => elixir_var(mod, name) for name in metadata)
    # Anonymous elixir modules can remain alive through their method definitions.
    # Keep their callbacks from retaining sampled frames or whole solver states.
    sampler.frames = Any[]
    sampler.mod = @__MODULE__
    for name in (:sol, :ode, :semi, :mesh, :solver, :imported_mesh, :callbacks,
                 :analysis_callback, :amr_callback, :amr_controller, :amr_indicator,
                 :source_terms, :boundary_conditions, :tfsf)
        if Base.invokelatest(isdefined, mod, name) &&
           !Base.invokelatest(isconst, mod, name)
            Core.eval(mod, Expr(:(=), name, nothing))
        end
    end
    return (; frames, metadata = values)
end

# A field panel has no scenario-specific layout or annotations.
function field_panel!(position, result, variable_index; variable, frame_index = 1,
                      case_index = 1, time = nothing, ylabel = "z", prefix = variable,
                      plot_mesh = false, colorrange = (-1.0f0, 1.0f0),
                      colormap = Reverse(:RdBu))
    frame = result.frames[frame_index]
    field = frame.fields[variable_index]
    title = time === nothing ? "$prefix at t = $(round(frame.t; digits = 3))" :
            lift(t -> "$prefix at t = $(round(t; digits = 3))", time)
    axis = Axis(position; title, titlealign = :left,
                xlabel = "x", ylabel, aspect = DataAspect())
    points = field.geometry.position
    limits!(axis, extrema(getindex.(points, 1))..., extrema(getindex.(points, 2))...)
    if colorrange === nothing
        limit = max(1.0f-6,
                    maximum(maximum(abs, f.fields[variable_index].values)
                            for f in result.frames))
        colorrange = (-limit, limit)
    end
    plot = mesh!(axis, field.geometry; color = field.values,
                 colormap, colorrange, shading = NoShading)
    wireframe = plot_mesh ?
                lines!(axis, field.outlines;
                       color = :lightgrey, linewidth = 0.5) : nothing
    return (; case_index, variable_index, axis, plot, wireframe)
end

function update_frame!(view, results, index)
    for panel in view.panels
        field = results[panel.case_index].frames[index].fields[panel.variable_index]
        # Update geometry and colors together, since AMR can change both lengths.
        GLMakie.update!(panel.plot; arg1 = field.geometry, color = field.values)
        if panel.wireframe !== nothing
            GLMakie.update!(panel.wireframe; arg1 = field.outlines)
        end
    end
    if view.probe_plots !== nothing
        probe = first(results).frames[index].probe
        GLMakie.update!(view.probe_plots.exact; arg2 = probe.exact)
        GLMakie.update!(view.probe_plots.numerical; arg2 = probe.numerical)
    end
    view.time[] = first(results).frames[index].t
    return nothing
end

function write_visualization(view, results; video, framerate = 30,
                             output_directory, output_name)
    mkpath(output_directory)
    path = joinpath(output_directory, output_name * (video ? ".mp4" : ".png"))
    if video
        record(view.figure, path, eachindex(first(results).frames); framerate) do index
            update_frame!(view, results, index)
        end
    else
        save(path, view.figure; px_per_unit = 2)
    end
    println("saved ", path)
    return (; path, results, view)
end

end # module MaxwellVisuals
