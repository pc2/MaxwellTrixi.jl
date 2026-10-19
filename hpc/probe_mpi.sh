#!/usr/bin/env bash
# MPI and HDF5 diagnostics for Julia on Otus. Run on a login node and send
# the log along:
#
#   bash hpc/probe_mpi.sh > probe_mpi.log 2>&1
#
# JULIA_MODULE and HDF5_MODULE override the modules. PROBE_SRUN=1 adds a
# two-rank srun test under SLURM_ACCOUNT. Every step continues on failure;
# the failures are the information.

JULIA_MODULE=${JULIA_MODULE:-lang/JuliaHPC/1.13.1-foss-2025a}
SLURM_ACCOUNT=${SLURM_ACCOUNT:-pc2-mitarbeiter}

section() { printf '\n==== %s ====\n' "$1"; }
show() { printf '\n$ %s\n' "$*"; "$@" 2>&1; }
julia_rank='using MPI; MPI.Init(); println("rank ", MPI.Comm_rank(MPI.COMM_WORLD), " of ", MPI.Comm_size(MPI.COMM_WORLD), " on ", gethostname()); MPI.Finalize()'
julia_hdf5='using HDF5; println("HDF5 ok: ", HDF5.API.libhdf5, " parallel=", HDF5.has_parallel())'
julia_both='using MPI, HDF5; MPI.Init(); println("MPI ok: ", MPI.Get_library_version()); println("HDF5 ok: ", HDF5.API.libhdf5, " parallel=", HDF5.has_parallel()); MPI.Finalize()'

section "host"
show hostname
show date -u

section "modules, including those behind gateway modules"
for name in Julia HDF5 OpenMPI MPIwrapper MPItrampoline; do
    show module avail -t "$name"
    show find_module "$name"
done

section "module show $JULIA_MODULE"
show module show "$JULIA_MODULE"

section "environment after loading $JULIA_MODULE"
module load "$JULIA_MODULE"
show module list
printf 'JULIA_LOAD_PATH=%s\nJULIA_DEPOT_PATH=%s\nEBROOTOPENMPI=%s\n' \
    "${JULIA_LOAD_PATH:-}" "${JULIA_DEPOT_PATH:-}" "${EBROOTOPENMPI:-}"
printf 'LD_LIBRARY_PATH:\n'
echo "${LD_LIBRARY_PATH:-}" | tr ':' '\n'
show which julia mpiexec mpirun srun
show julia --version
show mpiexec --version
printf '\n$ env | grep MPI,OMPI,PMIX,UCX,JULIA\n'
env | grep -E '^(MPI|OMPI|PMIX|UCX|JULIA)' | sort

section "preferences visible on Julia's load path"
show julia -e 'for env in Base.load_path()
    println(env)
    directory = endswith(env, ".toml") ? dirname(env) : env
    for name in ("LocalPreferences.toml", "Project.toml")
        path = joinpath(directory, name)
        isfile(path) || continue
        text = read(path, String)
        occursin("preferences", lowercase(text)) || continue
        println("---- ", path)
        print(text)
    end
end'

section "system OpenMPI libraries"
show ls "${EBROOTOPENMPI:-/nonexistent}/lib"
printf '\n$ readelf -d libmpi.so | rpath, needed\n'
readelf -d "${EBROOTOPENMPI:-/nonexistent}/lib/libmpi.so" 2>&1 | grep -iE 'rpath|runpath|needed'

section "HDF5 module built with this OpenMPI"
hdf5_found=$({ module avail -t HDF5; find_module HDF5; } 2>&1 | grep -oE '[A-Za-z0-9_]+/HDF5/[^ :]*gompi-2025a[^ :]*' | head -n 1)
HDF5_MODULE=${HDF5_MODULE:-$hdf5_found}
echo "HDF5_MODULE=$HDF5_MODULE"
if [ -n "$HDF5_MODULE" ]; then
    module load "$HDF5_MODULE"
    show module list
    echo "EBROOTHDF5=${EBROOTHDF5:-}"
    show ls "${EBROOTHDF5:-/nonexistent}/lib"
    printf '\n$ grep H5_HAVE_PARALLEL H5pubconf.h\n'
    grep -E 'H5_HAVE_PARALLEL' "${EBROOTHDF5:-/nonexistent}/include/H5pubconf.h" 2>&1
    printf '\n$ readelf -d libhdf5.so | rpath, needed\n'
    readelf -d "${EBROOTHDF5:-/nonexistent}/lib/libhdf5.so" 2>&1 | grep -iE 'rpath|runpath|needed'
    printf '\n$ ldd libhdf5.so | mpi\n'
    ldd "${EBROOTHDF5:-/nonexistent}/lib/libhdf5.so" 2>&1 | grep -iE 'mpi|open-pal|pmix|not found'
fi

STRIPPED=$(echo "${LD_LIBRARY_PATH:-}" | tr ':' '\n' | grep -vi openmpi | paste -sd:)
printf '\nLD_LIBRARY_PATH without OpenMPI:\n'
echo "$STRIPPED" | tr ':' '\n'

section "fresh project: MPIPreferences as the module leaves it, MPI.jl"
tmp=$(mktemp -d)
echo "project $tmp"
show julia --project="$tmp" -e 'using Pkg; Pkg.add(["MPIPreferences", "MPI", "HDF5"])'
show julia --project="$tmp" -e 'using MPIPreferences; println((binary = MPIPreferences.binary, abi = MPIPreferences.abi, libmpi = MPIPreferences.libmpi, mpiexec = MPIPreferences.mpiexec)); using MPI; MPI.versioninfo()'

section "A: HDF5.jl with the module environment as it is"
show julia --project="$tmp" -e "$julia_hdf5"

section "B: HDF5.jl and MPI.jl with OpenMPI removed from LD_LIBRARY_PATH"
show env LD_LIBRARY_PATH="$STRIPPED" julia --project="$tmp" -e "$julia_hdf5"
show env LD_LIBRARY_PATH="$STRIPPED" julia --project="$tmp" -e "$julia_both"

section "C: system MPI by absolute path, system HDF5, OpenMPI removed from LD_LIBRARY_PATH"
if [ -n "${EBROOTOPENMPI:-}" ]; then
    show julia --project="$tmp" -e "using MPIPreferences; MPIPreferences.use_system_binary(library_names = [\"$EBROOTOPENMPI/lib/libmpi.so\"], mpiexec = \"$EBROOTOPENMPI/bin/mpiexec\", export_prefs = false)"
fi
if [ -n "${EBROOTHDF5:-}" ]; then
    show env LD_LIBRARY_PATH="$STRIPPED" julia --project="$tmp" -e "using HDF5; HDF5.API.set_libraries!(\"$EBROOTHDF5/lib/libhdf5.so\", \"$EBROOTHDF5/lib/libhdf5_hl.so\")"
fi
show cat "$tmp/LocalPreferences.toml"
show env LD_LIBRARY_PATH="$STRIPPED" julia --project="$tmp" -e "$julia_both"
show env LD_LIBRARY_PATH="$STRIPPED" "${EBROOTOPENMPI:-/nonexistent}/bin/mpiexec" -n 2 julia --project="$tmp" -e "$julia_rank"

section "D: same preferences with the full module LD_LIBRARY_PATH"
show julia --project="$tmp" -e "$julia_both"

if [ "${PROBE_SRUN:-0}" = 1 ]; then
    section "E: two ranks through srun"
    show env LD_LIBRARY_PATH="$STRIPPED" srun -A "$SLURM_ACCOUNT" -p normal -t 00:05:00 -n 2 -c 1 --mem-per-cpu=1G julia --project="$tmp" -e "$julia_rank"
fi

section "done"
echo "project kept at $tmp"
