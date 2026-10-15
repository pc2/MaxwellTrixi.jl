# Diagnostics and validation

```@meta
CurrentModule = TrixiMaxwell
```

## Field energy and divergence

The energy diagnostic is the electromagnetic field contribution

```math
w_{\rm EM}=\tfrac12\left(\epsilon_\infty |E|^2+\mu|H|^2\right).
```

In a nondispersive physical region it satisfies the continuous balance

```math
\partial_t w_{\rm EM}+\nabla\cdot(E\times H)
=-\sigma|E|^2-E\cdot J_{\rm src}.
```

With dispersion, an additional ``-E\cdot\sum_kJ_k`` transfers energy between
fields and material oscillators. The reported `energy_total` is the field
energy above; it does not include oscillator or PML auxiliary energy.

The analysis callbacks also report broken, elementwise norms

```math
\|\nabla\cdot E_h\|_{L^2(\mathcal T_h)}^2
=\sum_K\int_K|\nabla\cdot E_h|^2dx,\qquad
\|\nabla\cdot E_h\|_{\infty,h}=\max_{K,a}|(\nabla\cdot E_h)(x_{K,a})|,
```

and likewise for ``H``. The infinity norm is sampled at solution nodes. These
norms exclude distributional jumps at element faces; they are not global Gauss-law
residuals for ``D`` and ``B`` across material interfaces. DGMulti uses its mass
and differentiation operators; curved meshes use their local metrics and
quadrature. DGSEM uses nodal derivatives and metric-weighted tensor quadrature.

The error-norm extensions for DGMulti and DGSEM report errors for the six
physical fields and mask the extra components. Validate material parameters and
auxiliary dynamics with their dedicated tests rather than interpreting those
zeros as an error estimate.

## Analytical time-domain references

The PEC cavity provides both the nondispersive, possibly lossy TM mode and a
lossless single-Drude-pole mode. Together with the Fresnel and dipole examples,
these test propagation, material interfaces, time-domain dispersion and source
strength against analytical solutions.

```@docs
initial_condition_cavity
```

Relevant tests are in `test/test_dgmulti_3d.jl` and `test/test_dgsem_3d.jl`:
cavity convergence and energy, Fresnel interface energy and convergence, dipole
probes, TF/SF leakage, and PML reflection. Curved import, interpolation and VTK
are covered by `test/test_meshes.jl` and the simulation tests. Unit and type tests
exercise flux consistency, axis/normal agreement, and `Float32`/`Float64` behavior.

## Surface Fourier transforms

Frequency-domain diagnostics are separate from the time-domain visualizations.
The surface callbacks currently operate on fixed DGMulti meshes. They accumulate
fields after accepted time steps rather than retaining the complete solution
history. The integration uses the actual step lengths, including variable ones.

```@docs
TrixiMaxwell.SurfaceTransformCallback
CrossSectionCallback
DetectorPlaneCallback
cross_sections
transmittance_reflectance
```

The field transform uses ``e^{-2\pi i f t}``. The resulting complex spectra can
be conjugated to match the ``e^{-i\omega t}`` phasor convention used by the
material references; the real power ratios are unchanged. Run long enough for
the pulse and relevant transients to leave the integration surfaces. Normalize
only at frequencies with appreciable incident signal. Detector planes must
consist of interior element faces in the total-field region.

## Mie and slab references

The Mie routine sums spherical multipoles to obtain scattering and extinction;
absorption follows by subtraction. Efficiencies become cross sections after
multiplication by the sphere's geometric area. The Airy formula sums repeated
reflections in a planar slab at normal incidence. Both are references for the
configured homogeneous media and geometry, rather than substitutes for general
inhomogeneous scattering simulations.

```@docs
mie_efficiencies
slab_transmittance_reflectance
```
