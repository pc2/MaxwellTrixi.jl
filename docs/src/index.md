# MaxwellTrixi.jl

MaxwellTrixi implements three-dimensional Maxwell equations in Trixi.jl. The
unknowns are the electric and magnetic fields. Optional state components carry
material parameters, polarization currents and PML auxiliary fields.

The implementation follows Trixi's equations × mesh × solver structure. Trixi
provides the DG operators, time integration interface, CFL control and adaptive
mesh refinement. MaxwellTrixi adds electromagnetic fluxes, material models,
excitation, boundary conditions, mesh import and diagnostics.

## Reading the implementation

| Topic | Mathematical role | Implementation |
|:--|:--|:--|
| [Equations and materials](@ref) | Curl equations and constitutive models | `src/equations/` |
| [DG discretization](@ref) | Volume derivatives, interface fluxes, source projection | `src/solvers/`, `src/sources/projected.jl` |
| [Sources and boundaries](@ref) | Incident fields, TF/SF, conductors and PML | `src/sources/`, `src/equations/maxwell_3d.jl` |
| [Meshes and output](@ref) | Geometry maps, material groups, interpolation and VTK | `src/meshes/`, `src/visualization/` |
| [Diagnostics and validation](@ref) | Divergence, energy, Fourier transforms and references | `src/callbacks_step/`, `src/analytic/`, `test/` |
| [Figures and videos](@ref) | Field slices, probe comparisons and adaptive meshes | `utils/visualize/`, `utils/paraview/` |

## Running an example

Use Julia 1.13 or newer and Trixi.jl `main`. From the repository root:

```sh
julia --project=examples -e 'using Pkg; Pkg.instantiate()'
julia --project=examples
```

Then run an elixir:

```julia
using Trixi, MaxwellTrixi, OrdinaryDiffEqLowStorageRK
trixi_include(pkgdir(MaxwellTrixi, "examples", "dgmulti_3d",
                     "elixir_maxwell_3d_cavity.jl"))
```

Elixirs combine a mesh, equations, initial and boundary conditions, a DG solver,
a semidiscretization and callbacks. Assignments such as `polydeg` or `tspan` can
be overridden through `trixi_include`. Imported meshes are downloaded on first
use; Gmsh meshes also require `using Gmsh`.

A useful presentation order is the cavity, Fresnel interface, TF/SF box, dipole,
PML comparison and scattering examples, followed by the adaptive P4est mesh.
The [figures and videos](@ref "Figures and videos") show what each example measures.
