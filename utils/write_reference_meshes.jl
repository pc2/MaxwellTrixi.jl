# Write every reference mesh of the registry as VTK files into meshes/vtk for
# inspection in ParaView, plus the cavity solution on the Gmsh cube.
#   env JULIA_LOAD_PATH=$PWD:$PWD/test:@stdlib julia utils/write_reference_meshes.jl
using Trixi
using MaxwellTrixi
using Gmsh
using OrdinaryDiffEqLowStorageRK

output = joinpath(MaxwellTrixi.default_mesh_directory(), "vtk")
mkpath(output)

for name in sort(collect(keys(MaxwellTrixi.MESH_REGISTRY)))
    path = download_mesh(name)
    imported = endswith(name, ".neu") ? read_gambit(path) : read_gmsh(path)
    files = write_mesh_vtk(imported, joinpath(output, first(splitext(name))))
    println(rpad(name, 32), imported, "\n    ", join(basename.(files), ", "))
end

trixi_include(joinpath(pkgdir(MaxwellTrixi), "examples", "dgmulti_3d",
                       "elixir_maxwell_3d_cavity_gmsh.jl"); tspan = (0.0, 1.5))
save_vtk_callback = SaveVtkCallback(dt = 0.05, output_directory = output,
                                    filename = "cavity_gmsh",
                                    solution_variables = cons2cons)
sol = solve(ode, CarpenterKennedy2N54(williamson_condition = false);
            dt = 1.0, ode_default_options()...,
            callback = CallbackSet(stepsize_callback, save_vtk_callback))
println("solution series: ", joinpath(output, "cavity_gmsh.pvd"), " with ",
        length(save_vtk_callback.affect!.affect!.entries), " frames")
