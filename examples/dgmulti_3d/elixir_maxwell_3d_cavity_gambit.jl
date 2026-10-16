using OrdinaryDiffEqLowStorageRK
using Trixi
using MaxwellTrixi

###############################################################################
# semidiscretization of the Maxwell equations on an imported Gambit mesh

equations = MaxwellEquations3D()
initial_condition = initial_condition_cavity

polydeg = 3
surface_flux = flux_upwind
solver = DGMulti(polydeg = polydeg,
                 element_type = Tet(),
                 approximation_type = Polynomial(),
                 surface_integral = SurfaceIntegralWeakForm(surface_flux),
                 volume_integral = VolumeIntegralWeakForm())

# cube [-1, 1]^3 with 986 tetrahedra from nodal-dg, boundary set "Wall"
mesh_file = download_mesh("F986.neu")
imported_mesh = read_gambit(mesh_file)
mesh = DGMultiMesh(solver, imported_mesh)

boundary_conditions = (; Wall = boundary_condition_perfect_electric_conductor)

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver;
                                    boundary_conditions)

###############################################################################
# ODE solvers, callbacks etc.

tspan = (0.0, 1.0)
ode = semidiscretize(semi, tspan)

summary_callback = SummaryCallback()

analysis_interval = 100
analysis_callback = AnalysisCallback(semi, interval = analysis_interval)
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
