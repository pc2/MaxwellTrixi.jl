# Figures and videos

Figures appear beside their feature explanations in
[Equations and materials](@ref), [Sources and boundaries](@ref) and
[DG discretization](@ref). When a matching video is available, it replaces the
figure. Use the player controls to play, pause or seek.

## Reproducing the visuals

Each scenario owns its settings and layout in `utils/visualize/`, with the same
filename as its simulation elixir. Videos use GLMakie, 241 frames at 30 fps,
fixed color scales and left-aligned updating titles. Still figures use CairoMakie
and can show several snapshot times.

From the repository root:

```sh
julia --project=utils/visualize -e 'using Pkg; Pkg.instantiate()'
julia --threads=1 --project=utils/visualize utils/visualize/make_all.jl --video
```

Omit `--video` for all still figures, or run an individual script from this table.
PNGs go to `docs/figures/`, MP4s to `docs/videos/`.

| Scenario | Script under `utils/visualize/` |
|:--|:--|
| Cavity | `elixir_maxwell_3d_cavity.jl` |
| Fresnel | `elixir_maxwell_3d_fresnel.jl` |
| TF/SF | `elixir_maxwell_3d_tfsf.jl` |
| Dipole | `elixir_maxwell_3d_dipole.jl` |
| PML | `elixir_maxwell_3d_pml.jl` |
| Dielectric sphere | `elixir_maxwell_3d_dielectric_sphere.jl` |
| PEC sphere | `elixir_maxwell_3d_pec_sphere.jl` |
| Periodic wave | `elixir_maxwell_3d_periodic.jl` |
| Dielectric TF/SF scattering | `elixir_maxwell_3d_mie.jl` |
| Adaptive dipole | `p4est_3d_dgsem/elixir_maxwell_3d_dipole.jl` |

[Building and publishing](@ref) explains local documentation builds and CI rendering.

## Full 3D adaptive mesh in ParaView

The GLMakie dipole slice has an analytical probe comparison. For inspection of
refinement throughout the three-dimensional volume, use
`utils/paraview/dipole_p4est.py` after the README's HDF5-to-VTK conversion. Its
clipped mesh can be rotated and animated interactively; this is the scenario
where ParaView adds information beyond the native slice videos.
