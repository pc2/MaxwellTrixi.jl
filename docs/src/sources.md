# Sources and boundaries

```@meta
CurrentModule = TrixiMaxwell
```

## Time signals and incident fields

Time signals provide their first and second derivatives analytically, which is
needed by the dipole current and its reference field. Plane waves are solutions
in a homogeneous, lossless, nondispersive background material. They can be used
as initial conditions, boundary data or TF/SF excitation. Superposition adds the
physical fields and retains one set of default material parameters.

```@docs
GaussianPulse
ModulatedGaussianPulse
signal_derivative
signal_second_derivative
TrixiMaxwell.AbstractIncidentField
PlaneWave
initial_condition_zero
```

```jldoctest
julia> using TrixiMaxwell

julia> pulse = GaussianPulse(0.4; delay = 1.4);

julia> pulse(1.4), signal_derivative(pulse, 1.4)
(1.0, -0.0)
```

### Periodic plane wave example

This periodic-domain example shows a plane wave propagating through the tetrahedral mesh.

![Periodic plane wave](assets/figures/periodic.png)

## Regularized electric dipole

The dipole injects an impressed electric current, so it enters the electric
field equation with a minus sign. Its spatial Gaussian has unit integral over
all space. `ProjectedSourceTerms` helps retain that strength on DGSEM meshes.
The analytical exterior reference assumes a homogeneous, lossless, nondispersive
background and accounts for Gaussian regularization of a Gaussian time pulse.
Compare it outside the source region and before boundary reflections return.

```@docs
HertzianDipole
HertzianDipoleField
```

### Dipole on tetrahedra example

The field slice accompanies a numerical-versus-analytical line probe. Source
regularization and spatial resolution both affect agreement near the source.

![Dipole on tetrahedra](assets/figures/dipole.png)

## Total-field/scattered-field injection

TF/SF injection confines the incident wave to a chosen region. With no scatterer,
the exterior should remain close to zero; this is a useful leakage test.

```@docs
TotalFieldScatteredField
FluxTotalFieldScatteredField
```

On DGMulti, `TotalFieldScatteredField` is installed through
`boundary_conditions`; it recomputes selected interior face fluxes during the
boundary-flux stage, where time and face coordinates are available. On P4est
and T8code DGSEM, `FluxTotalFieldScatteredField` wraps the surface flux and
records the current stage time in a specialized RHS hook.

The TF/SF surface must follow element faces in the background medium. The DGSEM
implementation rejects a TF/SF surface crossing a mortar; refine both sides
of that surface equally. Its marks are rebuilt when the element, interface or
mortar counts change. Start with a delayed incident pulse and a consistent
initial state; injection does not repair inconsistent initial data.

### TF/SF in free space example

With no scatterer, the stored field outside the dashed TF box stays close to zero. This visualizes cancellation of the incident field on the scattered-field side.

![TF/SF in free space](assets/figures/tfsf.png)

### PEC sphere with TF/SF example

The PEC sphere reflects the injected pulse. The stored field is total inside the dashed box and scattered outside.

![PEC sphere with TF/SF](assets/figures/pec_sphere.png)

### Dielectric TF/SF scattering example

The dielectric sphere scatters the injected pulse. This slice uses affine tetrahedra; the numerical Mie example also supports curved geometry.

![Dielectric TF/SF scattering](assets/figures/mie.png)

## Physical boundary conditions

For outward unit normal ``n``, the ideal conditions are

```math
n\times E=0\quad\text{(PEC)},\qquad
n\times H=0\quad\text{(PMC)}.
```

The implementation supplies reflected exterior fields to the numerical flux.
Only tangential components enter the Maxwell normal flux. Silver–Mueller sets
the incoming characteristic to zero; it is exact for an outgoing plane wave at
normal incidence and approximate for oblique waves. Prescribed incident fields
enter as exterior states of the scheme's surface flux; with `flux_upwind` only
their incoming characteristic enters the domain.

```@docs
boundary_condition_perfect_electric_conductor
boundary_condition_perfect_magnetic_conductor
boundary_condition_silver_mueller
BoundaryConditionIncidentField
```

## Uniaxial perfectly matched layer

UPML adds local damping and six auxiliary unknowns. Its profile vanishes in the
physical region and grows towards the outer boundary. The directional damping
rates ``\sigma_x,\sigma_y,\sigma_z`` below are PML parameters, distinct from the
material's physical Ohmic conductivity ``\sigma``.

```@docs
PMLProfile
SourceTermsPML
CombinedSourceTerms
```

The layer must continue the adjacent background material. The examples combine
its source with the dipole and terminate the outer boundary with
Silver–Mueller. `test/test_dgmulti_3d.jl` and `test/test_dgsem_3d.jl` compare
residual reflection or remaining energy with and without PML.

### PML comparison example

The side-by-side comparison shows UPML and Silver–Mueller alone. Both use
the same narrow color scale. The stronger outgoing pulse saturates it, making
smaller late reflections visible.

![PML comparison](assets/figures/pml.png)

