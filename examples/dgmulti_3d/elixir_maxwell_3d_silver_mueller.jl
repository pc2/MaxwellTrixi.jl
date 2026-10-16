using OrdinaryDiffEqLowStorageRK
using Trixi
using MaxwellTrixi

###############################################################################
# semidiscretization of the Maxwell equations

equations = MaxwellEquations3D()

@doc raw"""
    initial_condition_gaussian_pulse(x, t, equations::MaxwellEquations3D)

Gaussian plane-wave pulse travelling in the positive x direction,
``E_y = Z H_z = \exp(-((x - c t) / 0.2)^2)``. The exact free-space solution leaves
the domain ``[-1, 1]^3`` through [`boundary_condition_silver_mueller`](@ref) on the
x faces, so the errors and the energy at the final time measure the reflection
of the absorbing boundary at normal incidence.
"""
function initial_condition_gaussian_pulse(x, t, equations::MaxwellEquations3D)
    RealT = eltype(x)
    width = convert(RealT, 0.2)
    c = speed_of_light(equations)
    Z = impedance(equations)

    g = exp(-((x[1] - c * t) / width)^2)
    z = zero(g)

    return SVector(z, g, z, z, z, g / Z)
end

initial_condition = initial_condition_gaussian_pulse

boundary_conditions = (; entire_boundary = boundary_condition_silver_mueller)

polydeg = 3
surface_flux = flux_upwind
solver = DGMulti(polydeg = polydeg,
                 element_type = Tet(),
                 approximation_type = Polynomial(),
                 surface_integral = SurfaceIntegralWeakForm(surface_flux),
                 volume_integral = VolumeIntegralWeakForm())

cells_per_dimension = (4, 4, 4)

mesh = DGMultiMesh(solver, cells_per_dimension;
                   coordinates_min = (-1.0, -1.0, -1.0),
                   coordinates_max = (1.0, 1.0, 1.0),
                   periodicity = (false, true, true))

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver;
                                    boundary_conditions)

###############################################################################
# ODE solvers, callbacks etc.

tspan = (0.0, 2.5)
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
            dt = 1.0, #overwritten by stepsize callback
            ode_default_options()..., callback = callbacks)
