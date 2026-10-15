# TrixiMaxwell.jl

Discontinuous Galerkin time-domain solver for Maxwell's equations built on [Trixi.jl](https://github.com/trixi-framework/Trixi.jl).

Started at the JuliaCon 2026 hackathon to learn `Trixi.jl`.

## Current features

- Maxwell's curl equations for `(E, H)` in normalized units (`c = Z = 1`, relative `epsilon`, `mu`, normalized conductivity `sigma`) 
- Materials: homogeneous, or piecewise constant per element carried as passive state components, with one-sided interface fluxes on the `DGSEM` meshes
- Dispersive media: Drude and Lorentz poles through polarization currents, homogeneous or per element, with a gold preset (Vial et al. 2005)
- Boundaries: perfect electric and magnetic conductors, Silver-Mueller, incident fields, uniaxial perfectly matched layer
- Sources: Hertzian dipole with analytic reference field, plane waves with Gaussian or modulated signals, total-field/scattered-field injection on tetrahedra and `P4estMesh`, quadrature-projected sources for `DGSEM`
- Gambit and Gmsh reader, quadratic Gmsh tetrahedra give curved elements
- VTK output writer with ParaView scripts in `utils/paraview/`, point probes (tetrahedra and all `DGSEM` meshes), divergence diagnostics
- On-the-fly Fourier transform on surfaces (tetrahedra): scattering, extinction and absorption cross sections on the TF/SF surface, transmittance and reflectance on detector planes, with Mie series and Airy formula as references
- Solvers: `DGMulti` on tetrahedra, `DGSEM` on `TreeMesh`, `StructuredMesh`, `P4estMesh` and `T8codeMesh`

Elixirs can be found in `examples/`, grouped by mesh type.
The tetrahedral ones in `examples/dgmulti_3d/` use meshes from [nodal-dg](https://github.com/tcew/nodal-dg), [MIDG2](https://github.com/tcew/MIDG2) and [OpenSEMBA](https://github.com/OpenSEMBA/dgtd).
The `DGSEM` mesh types all run the cavity; `P4estMesh` additionally covers the Fresnel, dipole, PML and TF/SF cases, also with adaptive refinement.

Currently they cover
- PEC cavity
- periodic plane wave
- a lossy cavity
- Silver-Mueller absorption
- Fresnel half space (tetrahedra and `P4estMesh`)
- dielectric sphere, and its scattering cross section against Mie theory on curved tetrahedra
- dielectric slab transmittance and reflectance against the Airy formula, also with Drude and Lorentz poles
- cavity filled with a Drude medium, and a Drude sphere against Mie theory
- extinction spectrum of a 40 nm gold nanosphere against Mie theory
- dipole in free space (tetrahedra and `P4estMesh` with adaptive refinement) and in a PML box (tetrahedra and `P4estMesh`)
- TF/SF injection without scatterer (tetrahedra and `P4estMesh`) and scattering off a PEC sphere

## Installation

The package currently depends on a Trixi.jl branch with 3D `DGMulti` slicing, pinned in `Project.toml` through `[sources]`. In a Julia 1.11 or newer session:

```julia
using Pkg
Pkg.develop(path = "path/to/TrixiMaxwell.jl")
Pkg.instantiate()
```

Reading Gmsh files needs the optional `Gmsh` package, which activates the `TrixiMaxwellGmshExt` extension:

```julia
Pkg.add("Gmsh")
```

An ODE integrator is required to run elixirs, for example `OrdinaryDiffEqLowStorageRK`.

## Running an elixir

```julia
using Trixi, TrixiMaxwell, OrdinaryDiffEqLowStorageRK
trixi_include(pkgdir(TrixiMaxwell, "examples", "dgmulti_3d", "elixir_maxwell_3d_cavity.jl"))
```

Keyword arguments of `trixi_include` override the variables of the elixir, for example `tspan = (0.0, 0.5)` or `polydeg = 2`.

Elixirs on imported meshes download their mesh on first use.

## Figures and GLMakie videos

Each file in `utils/visualize/` matches its simulation elixir's filename and
contains that scenario's slice settings, figure layout, overlays and video
configuration. The P4est dipole uses the subdirectory `p4est_3d_dgsem/` to
distinguish it from the DGMulti dipole. `common.jl` contains shared sampling,
interpolation and plot-update routines.

Prepare the environment with Julia 1.13, then run a scenario:

```bash
julia --project=utils/visualize -e 'using Pkg; Pkg.instantiate()'
# One figure or video:
julia --project=utils/visualize utils/visualize/elixir_maxwell_3d_pml.jl
julia --project=utils/visualize utils/visualize/elixir_maxwell_3d_pml.jl --video
# AMR dipole:
julia --project=utils/visualize utils/visualize/p4est_3d_dgsem/elixir_maxwell_3d_dipole.jl --video
# All figures or all videos:
julia --project=utils/visualize utils/visualize/make_all.jl
julia --project=utils/visualize utils/visualize/make_all.jl --video
```

PNGs go to `docs/figures/` and MP4s to `docs/videos/`. Scenarios cover cavity,
Fresnel, TF/SF, dipole, AMR dipole, PML, dielectric sphere, PEC sphere,
periodic waves and Mie scattering.

Video simulations run for twice the span of the original animations, while
still figures retain their original snapshot times. Videos use 241 frames at
30 fps by default, fixed color scales and left-aligned updating titles. Dipole
videos update both the field slice and the numerical versus
analytical line probe. The P4est video captures the current mesh with each frame,
so refinement and coarsening remain synchronized with the field and probe.
PML retains the side-by-side comparison and narrow scale of its static figure;
the stronger outgoing pulse saturates that scale, highlighting late reflections.
Imported tetrahedra use affine geometry for the current native slicer. TF/SF
outlines mark total field inside and scattered field outside.

Use `trixi_include` to override a visualization's assignments, just as with a
simulation elixir. For example, for a short preview in `julia --project=utils/visualize`:

```julia
using Trixi
trixi_include("utils/visualize/elixir_maxwell_3d_pml.jl";
              video = true, frame_times = [0.0, 0.05, 0.1],
              simulation_overrides = (; polydeg = 1, cells_per_dimension = (2, 2, 2)))
```

## ParaView output

ParaView is used only for inspecting the full 3D adaptive mesh of the P4est
dipole. Its single view combines a clipped half-domain element mesh with a
`Hy` slice near `y = 0`, so you can rotate the view and follow refinement
throughout the volume. The CairoMakie figure and GLMakie video show the same
simulation as a 2D slice with the analytical probe comparison.

The script opens at the first saved frame (`t = 0`). Press Play to animate;
change the clipping plane in the pipeline to inspect another part of the mesh.
Set `PV_TIME` to choose another initial time (rounded to the nearest saved
frame), or `DIPOLE_PVD` and `DIPOLE_MESH_PVD` for other collection paths.

The dipole elixir uses Trixi.jl's own `SaveSolutionCallback` and is converted with [Trixi2Vtk.jl](https://github.com/trixi-framework/Trixi2Vtk.jl). The P4est dipole carries the callback; after running it,

```julia
using Trixi2Vtk
trixi2vtk(joinpath("out", "solution_*.h5"), output_directory = joinpath("out", "vtk"),
          pvd = "dipole")
trixi2vtk(joinpath("out", "solution_*.h5"), output_directory = joinpath("out", "vtk_mesh"),
          nvisnodes = 2, pvd = "dipole")
```

The first call preserves the high-order field representation in Lagrange hexahedra; the second uses only the element corners for a linear mesh overlay. Then `paraview --script=utils/paraview/dipole_p4est.py`.

For a headless preview after conversion:

```sh
PV_SCREENSHOT=/tmp/amr.png pvpython utils/paraview/dipole_p4est.py
```

The dipole elixir saves the initial and final states and every 100 accepted steps. The number of frames and their sizes depend on CFL stepping and the evolving adaptive mesh. `trixi_include(elixir; save_solution_interval = 20)` samples the animation more frequently. The explicit `pvd` names above keep the script paths independent of the saved step numbers.

Trixi2Vtk v0.3.33 reads 3D `P4estMesh` refinement levels using the 2D p4est struct layout, so its converted `levels` cell data are unreliable. The dipole script uses element edges to show refinement geometrically instead of coloring by these levels. Check whether this converter issue has been fixed when using another version.

## Tests

```julia
using Pkg
Pkg.test("TrixiMaxwell")
```

## Figures

The figures below are produced by the scenario scripts in `utils/visualize/` using
CairoMakie. Run `julia --project=utils/visualize utils/visualize/make_all.jl` to regenerate
them, or add `--video` for their GLMakie animations.

PEC cavity with exact TM mode.

![cavity mode](docs/figures/cavity_mode.png)

Gaussian pulse hitting a dielectric half space at `x = 0` with exact Fresnel solution.

![Fresnel](docs/figures/fresnel.png)

Total-field/scattered-field box in free space.

![TF/SF](docs/figures/tfsf.png)

Hertzian dipole on tetrahedra. Point probe compares with the exact solution.

The source is narrower than the elements around it can resolve, which shows in the slice.

![dipole](docs/figures/dipole.png)

The same dipole with `DGSEM` on `P4estMesh` and adaptive mesh refinement, starting from the same 8 x 8 x 8 cells. The elements around the source are refined twice, the pulse is followed with one refinement level and by `t = 2` fills the box.

![dipole on P4estMesh](docs/figures/dipole_p4est.png)

Comparison of UPML with Silver-Mueller boundary condition.

![PML](docs/figures/pml.png)

Dielectric sphere (`epsilon = 2.25`) scattering with gaussian plane-wave intiatial condition.

![dielectric sphere](docs/figures/dielectric_sphere.png)

PEC sphere in a box. The box is used to inject gaussian plane-wave with TF/SF.

![PEC sphere](docs/figures/pec_sphere.png)

## Formatting

Following the Trixi.jl style, using `utils/trixi-format.jl` from `Trixi.jl`.

## License

MIT, see `LICENSE`.
