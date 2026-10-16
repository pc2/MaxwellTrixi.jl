using OrdinaryDiffEqLowStorageRK
using Trixi
using MaxwellTrixi
using Gmsh

###############################################################################
# semidiscretization of the Maxwell equations: plane wave scattering off a PEC sphere

equations = MaxwellEquations3D()

# Gaussian plane-wave pulse along z, polarized in x, delayed so that it starts
# outside the total-field box
incident_field = PlaneWave((0.0, 0.0, 1.0), (1.0, 0.0, 0.0),
                           GaussianPulse(0.5; delay = 3.5))

initial_condition = initial_condition_zero

polydeg = 2
surface_flux = flux_upwind
solver = DGMulti(polydeg = polydeg,
                 element_type = Tet(),
                 approximation_type = Polynomial(),
                 surface_integral = SurfaceIntegralWeakForm(surface_flux),
                 volume_integral = VolumeIntegralWeakForm())

# PEC sphere r = 1 inside a TFSF box of half-side 1.5 and an absorbing sphere r = 4;
# the file names the sphere surface "pec" but tags its triangles with 1
mesh_file = download_mesh("3D_RCS_PEC_1m.msh")
imported_mesh = read_gmsh(mesh_file)
mesh = DGMultiMesh(solver, imported_mesh)

is_total_field(x) = all(abs.(x) .< 1.5)
tfsf = TotalFieldScatteredField(incident_field, mesh, is_total_field)

boundary_conditions = (; tag_1 = boundary_condition_perfect_electric_conductor,
                       sma = boundary_condition_silver_mueller,
                       tfsf = tfsf)

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver;
                                    boundary_conditions)

###############################################################################
# ODE solvers, callbacks etc.

tspan = (0.0, 8.0)
ode = semidiscretize(semi, tspan)

summary_callback = SummaryCallback()

analysis_interval = 100
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
