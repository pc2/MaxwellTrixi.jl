using OrdinaryDiffEqLowStorageRK
using Trixi
using TrixiMaxwell

###############################################################################
# semidiscretization of the Maxwell equations with a Hertzian dipole inside a
# uniaxial perfectly matched layer

equations = MaxwellEquations3D(UPML())

dipole = HertzianDipole((0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 0.1,
                        GaussianPulse(0.4; delay = 1.4))

# exact exterior field of the regularized dipole for comparison, see the tests
dipole_field = HertzianDipoleField(dipole, equations)

# physical region [-1, 1]^3, PML shell of thickness 0.5 up to the domain boundary
coordinates_min = (-1.5, -1.5, -1.5)
coordinates_max = (1.5, 1.5, 1.5)
pml_thickness = 0.5
pml_profile = PMLProfile(coordinates_min, coordinates_max, pml_thickness)

source_terms = CombinedSourceTerms(SourceTermsPML(pml_profile), dipole)

initial_condition = initial_condition_zero

boundary_conditions = (; entire_boundary = boundary_condition_silver_mueller)

polydeg = 2
surface_flux = flux_upwind
solver = DGMulti(polydeg = polydeg,
                 element_type = Tet(),
                 approximation_type = Polynomial(),
                 surface_integral = SurfaceIntegralWeakForm(surface_flux),
                 volume_integral = VolumeIntegralWeakForm())

# two cells across the layer
cells_per_dimension = (12, 12, 12)

mesh = DGMultiMesh(solver, cells_per_dimension;
                   coordinates_min, coordinates_max,
                   periodicity = (false, false, false))

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver;
                                    boundary_conditions, source_terms)

###############################################################################
# ODE solvers, callbacks etc.

# the pulse peak enters the layer at t = 2.4; afterwards only reflections remain
tspan = (0.0, 4.0)
saveat = ()
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
            saveat = saveat,
            tstops = saveat,
            ode_default_options()..., callback = callbacks)
