using OrdinaryDiffEqLowStorageRK
using Trixi
using MaxwellTrixi

###############################################################################
# semidiscretization of the Maxwell equations with a total-field/scattered-field box

equations = MaxwellEquations3D()

# Gaussian plane-wave pulse along x, polarized in z, delayed so that it starts
# outside the total-field box
incident_field = PlaneWave((1.0, 0.0, 0.0), (0.0, 0.0, 1.0),
                           GaussianPulse(0.25; delay = 1.5))

initial_condition = initial_condition_zero

polydeg = 3
surface_flux = flux_upwind
solver = DGMulti(polydeg = polydeg,
                 element_type = Tet(),
                 approximation_type = Polynomial(),
                 surface_integral = SurfaceIntegralWeakForm(surface_flux),
                 volume_integral = VolumeIntegralWeakForm())

# the faces of the box [-0.5, 0.5]^3 coincide with element faces
cells_per_dimension = (8, 8, 8)

mesh = DGMultiMesh(solver, cells_per_dimension;
                   coordinates_min = (-1.0, -1.0, -1.0),
                   coordinates_max = (1.0, 1.0, 1.0),
                   periodicity = (false, false, false))

is_total_field(x) = all(abs.(x) .< 0.5)
tfsf = TotalFieldScatteredField(incident_field, mesh, is_total_field)

# without a scatterer the field outside the box stays zero and the pulse leaves
# the box through its far face; the absorbing boundary only sees discretization errors
boundary_conditions = (; entire_boundary = boundary_condition_silver_mueller,
                       tfsf = tfsf)

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver;
                                    boundary_conditions)

###############################################################################
# ODE solvers, callbacks etc.

tspan = (0.0, 3.5)
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
