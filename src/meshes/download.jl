const NODAL_DG_GRIDS = "https://raw.githubusercontent.com/tcew/nodal-dg/master/nudg%2B%2B/trunk/Grid/3D/"
const MIDG2_MESHES = "https://raw.githubusercontent.com/tcew/MIDG2/master/Meshes/"
const OPENSEMBA_INPUTS = "https://raw.githubusercontent.com/OpenSEMBA/dgtd/main/testData/maxwellInputs/"

"""
    MESH_REGISTRY

Reference meshes available through [`download_mesh`](@ref). Gambit files come
from nodal-dg (Hesthaven, Warburton) and MIDG2 (Warburton), Gmsh meshes and the
sphere-in-box geometry from OpenSEMBA/dgtd (BSD-3-Clause). The `.geo` file is
meshed on demand by [`read_gmsh`](@ref) at any `size_factor`.
"""
const MESH_REGISTRY = Dict{String, String}("cubeK5.neu" => NODAL_DG_GRIDS * "cubeK5.neu",
                                           "cubeK86.neu" => NODAL_DG_GRIDS * "cubeK86.neu",
                                           "cubeK268.neu" => NODAL_DG_GRIDS * "cubeK268.neu",
                                           "F072.neu" => NODAL_DG_GRIDS * "F072.neu",
                                           "F986.neu" => NODAL_DG_GRIDS * "F986.neu",
                                           "cube.neu" => NODAL_DG_GRIDS * "cube.neu",
                                           "sphere.neu" => NODAL_DG_GRIDS * "sphere.neu",
                                           "Sphere_1074.neu" => NODAL_DG_GRIDS *
                                                                "Sphere_1074.neu",
                                           "FS_K01022.neu" => MIDG2_MESHES * "FS_K01022.neu",
                                           "3D_PEC.msh" => OPENSEMBA_INPUTS *
                                                           "3D_PEC/3D_PEC.msh",
                                           "3D_TFSF.msh" => OPENSEMBA_INPUTS *
                                                            "3D_TFSF/3D_TFSF.msh",
                                           "3D_Dipole_Sphere_Slice.msh" => OPENSEMBA_INPUTS *
                                                                           "3D_Dipole_Sphere_Slice/3D_Dipole_Sphere_Slice.msh",
                                           "3D_RCS_PEC_1m.msh" => OPENSEMBA_INPUTS *
                                                                  "3D_RCS_PEC_1m/3D_RCS_PEC_1m.msh",
                                           "3D_RCS_Sphere_Box_05m_G1.msh" => OPENSEMBA_INPUTS *
                                                                             "3D_RCS_Sphere_Box_05m_G1/3D_RCS_Sphere_Box_05m_G1.msh",
                                           "3D_Resonant_Sphere.msh" => OPENSEMBA_INPUTS *
                                                                       "3D_Resonant_Sphere/3D_Resonant_Sphere.msh",
                                           "3D_RCS_SGBC_Sphere_Box_G1.msh" => OPENSEMBA_INPUTS *
                                                                              "3D_RCS_SGBC_Sphere_Box_G1/3D_RCS_SGBC_Sphere_Box_G1.msh",
                                           "3D_RCS_SGBC_Sphere_Box.geo" => OPENSEMBA_INPUTS *
                                                                           "3D_RCS_SGBC_Sphere_Box.geo")

default_mesh_directory() = joinpath(pkgdir(MaxwellTrixi), "meshes")

"""
    download_mesh(name; directory = default_mesh_directory())

Return the local path of the reference mesh `name` from [`MESH_REGISTRY`](@ref),
downloading it into `directory` unless the file is already there.
"""
function download_mesh(name::AbstractString; directory = default_mesh_directory())
    if !haskey(MESH_REGISTRY, name)
        known = join(sort(collect(keys(MESH_REGISTRY))), ", ")
        throw(ArgumentError("unknown mesh $name, known meshes: $known"))
    end
    mkpath(directory)
    return Trixi.download(MESH_REGISTRY[name], joinpath(directory, name))
end
