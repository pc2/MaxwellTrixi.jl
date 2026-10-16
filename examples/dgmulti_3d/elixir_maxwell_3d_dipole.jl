using OrdinaryDiffEqLowStorageRK
using Trixi
using MaxwellTrixi

###############################################################################
# semidiscretization of the Maxwell equations with a Hertzian dipole source

equations = MaxwellEquations3D()

# dipole along z at the origin; the time signal is wider than the spatial
# regularization so that the radiated field follows the point dipole closely
dipole = HertzianDipole((0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 0.1,
                        GaussianPulse(0.4; delay = 1.4))
source_terms = dipole

# exact exterior field of the regularized dipole for comparison, see the tests
dipole_field = HertzianDipoleField(dipole, equations)

initial_condition = initial_condition_zero

boundary_conditions = (; entire_boundary = boundary_condition_silver_mueller)

polydeg = 3
surface_flux = flux_upwind
solver = DGMulti(polydeg = polydeg,
                 element_type = Tet(),
                 approximation_type = Polynomial(),
                 surface_integral = SurfaceIntegralWeakForm(surface_flux),
                 volume_integral = VolumeIntegralWeakForm())

cells_per_dimension = (8, 8, 8)

mesh = DGMultiMesh(solver, cells_per_dimension;
                   coordinates_min = (-1.0, -1.0, -1.0),
                   coordinates_max = (1.0, 1.0, 1.0),
                   periodicity = (false, false, false))

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver;
                                    boundary_conditions, source_terms)

###############################################################################
# ODE solvers, callbacks etc.

# the pulse peak reaches the boundary at t = 2.4; until then the domain is free space
tspan = (0.0, 2.0)
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
