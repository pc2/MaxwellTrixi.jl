using OrdinaryDiffEqLowStorageRK
using Trixi
using MaxwellTrixi
using Gmsh

###############################################################################
# semidiscretization of the Maxwell equations with a dielectric sphere

equations = MaxwellEquations3D(Heterogeneous())

sphere_radius = 0.5
sphere_material = Material(epsilon = 2.25)

@doc raw"""
    initial_condition_pulse_z(x, t, equations::MaxwellEquations3D{Heterogeneous})

Gaussian plane-wave pulse in vacuum travelling in the positive z direction,
``E_x = H_y = \exp(-((z - t - z_0) / w)^2)``, started in front of the sphere.
The material components are the vacuum defaults; the sphere is set afterwards
with [`set_materials!`](@ref).
"""
function initial_condition_pulse_z(x, t, equations::MaxwellEquations3D{Heterogeneous})
    RealT = eltype(x)
    z0 = convert(RealT, -1.5)
    width = convert(RealT, 0.25)
    g = exp(-((x[3] - t - z0) / width)^2)
    z = zero(g)
    return SVector(g, z, z, z, g, z, one(RealT), one(RealT), z)
end
initial_condition = initial_condition_pulse_z

material_at(x) = sum(abs2, x) < sphere_radius^2 ? sphere_material : Material()

# outer sphere of radius 2.5 absorbs; the TFSF and SGBC surfaces are interior
boundary_conditions = (; SMA = boundary_condition_silver_mueller)

polydeg = 3
surface_flux = flux_upwind
solver = DGMulti(polydeg = polydeg,
                 element_type = Tet(),
                 approximation_type = Polynomial(),
                 surface_integral = SurfaceIntegralWeakForm(surface_flux),
                 volume_integral = VolumeIntegralWeakForm())

# sphere r = 0.5 inside a TFSF box of half-side 0.9 and an absorbing sphere r = 2.5
# smaller size_factor refines all regions; 1.0 gives a 28k-tet mesh with 979 tets in the sphere
size_factor = 2.0
mesh_file = download_mesh("3D_RCS_SGBC_Sphere_Box.geo")
imported_mesh = read_gmsh(mesh_file; size_factor)
mesh = DGMultiMesh(solver, imported_mesh)

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver;
                                    boundary_conditions)

###############################################################################
# ODE solvers, callbacks etc.

tspan = (0.0, 4.0)
ode = semidiscretize(semi, tspan)
set_materials!(ode.u0, semi, material_at)

summary_callback = SummaryCallback()

analysis_interval = 200
analysis_callback = AnalysisCallback(semi, interval = analysis_interval,
                                     analysis_errors = Symbol[])
alive_callback = AliveCallback(analysis_interval = analysis_interval)

cfl = 0.5
stepsize_callback = StepsizeCallback(cfl = cfl)

callbacks = CallbackSet(summary_callback, analysis_callback, alive_callback,
                        stepsize_callback)

###############################################################################
# run the simulation

sol = solve(ode, CarpenterKennedy2N54(williamson_condition = false);
            dt = 1.0, # overwritten by the stepsize callback
            ode_default_options()..., callback = callbacks)
