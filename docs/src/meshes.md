# Meshes and output

```@meta
CurrentModule = MaxwellTrixi
```

## Import and geometry

The import layer first constructs a solver-independent `ImportedMesh` containing
vertices, tetrahedral connectivity, volume groups and tagged face sets. Negative
orientations are corrected. Boundary tags are mapped to the names used by the
semidiscretization; each exterior face must belong to exactly one boundary set
unless untagged boundaries are explicitly allowed.

```@docs
ImportedMesh
read_gambit
read_gmsh
Trixi.DGMultiMesh(::Trixi.DGMulti{3}, ::ImportedMesh)
MaxwellTrixi.face_set_key
MaxwellTrixi.boundary_face_sets
MaxwellTrixi.MESH_REGISTRY
download_mesh
```

Quadratic Gmsh elements retain their edge nodes and use a quadratic geometry
map ``x=\Phi_K(r)``. Physical differentiation and quadrature use the map's
metric terms and ``J=\det(\partial\Phi_K/\partial r)``. The solution degree is
independent of the geometry degree. Higher-order imported Gmsh geometry is
reduced to its corner vertices; it is not retained at arbitrary order.

## Point evaluation

For a point located in element ``K``, interpolation evaluates

```math
u_h(x)=\sum_a u_{K,a}\,\ell_a(\Phi_K^{-1}(x)).
```

The evaluator locates points once and caches their element and interpolation
weights. Affine tetrahedra are located by barycentric coordinates. Curved
tetrahedra and DGSEM hexahedra invert the element map by Newton iteration;
DGSEM then interpolates with the tensor-product basis. Rebuild an evaluator
after mesh adaptation. A point on a DG interface receives one element trace
rather than an average of both traces.

```@docs
PointEvaluator
```

## VTK and ParaView

The package's VTK solution writer targets DGMulti tetrahedra, including curved
geometry. It exports high-order Lagrange cells and can write a PVD time
collection. DGSEM output uses Trixi's `SaveSolutionCallback` and Trixi2Vtk instead.
These are different output paths.

```@docs
write_mesh_vtk
write_solution_vtk
SaveVtkCallback
```

The P4est dipole ParaView script is in `utils/paraview/dipole_p4est.py`. It shows
actual element edges in a clipped half-domain and an ``H_y`` slice. The field
and linear-mesh collections must contain matching times. The repository README
contains the conversion commands. Rendering from element edges avoids relying
on refinement-level cell data from the converter.

## Native field slices

`PlotData2D` on Trixi `main` provides slices of three-dimensional affine DGMulti
tetrahedra. This is the path used by the tetrahedral figure and video scripts.
Curved tetrahedral slicing is currently unsupported by that native path; the
Mie visualization requests an affine mesh explicitly, while the numerical
curved-mesh examples remain available.

The P4est visualization uses a Cartesian hexahedral slice routine. It preserves
separate DG traces and element outlines and updates geometry together with the
field values during AMR. It is not a general curved-hexahedron slicer.
