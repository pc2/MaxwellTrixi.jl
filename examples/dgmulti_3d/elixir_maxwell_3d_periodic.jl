using OrdinaryDiffEqLowStorageRK
using Trixi
using MaxwellTrixi

###############################################################################
# semidiscretization of the Maxwell equations

equations = MaxwellEquations3D()
initial_condition = initial_condition_convergence_test

solver = DGMulti(polydeg = 3,
                 element_type = Tet(),
                 approximation_type = Polynomial(),
                 surface_integral = SurfaceIntegralWeakForm(flux_upwind),
                 volume_integral = VolumeIntegralWeakForm())

cells_per_dimension = (2, 2, 2)

mesh = DGMultiMesh(solver, cells_per_dimension;
                   coordinates_min = (0.0, 0.0, 0.0),
                   coordinates_max = (1.0, 1.0, 1.0),
                   periodicity = true)

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver;
                                    boundary_conditions = boundary_condition_periodic)

###############################################################################
# ODE solvers, callbacks etc.

tspan = (0.0, 0.25)
saveat = ()
ode = semidiscretize(semi, tspan)

stepsize_callback = StepsizeCallback(cfl = 0.5)
analysis_callback = AnalysisCallback(semi, interval = 10)

callbacks = CallbackSet(SummaryCallback(),
                        AliveCallback(alive_interval = 10),
                        analysis_callback,
                        stepsize_callback)

###############################################################################
# run the simulation

sol = solve(ode, CarpenterKennedy2N54(williamson_condition = false);
            dt = stepsize_callback(ode),
            saveat = saveat,
            tstops = saveat,
            ode_default_options()...,
            callback = callbacks)
