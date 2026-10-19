#!/usr/bin/env bash
# Tests the MPItrampoline route on Otus: MPIwrapper built against the system
# OpenMPI, then MPI.jl, HDF5.jl, P4est.jl and T8code.jl through
# MPItrampoline_jll with the module environment left as it is. Run on a login
# node and send the log:
#
#   bash hpc/probe_mpitrampoline.sh > probe_mpitrampoline.log 2>&1
#
# PREFIX keeps the MPIwrapper installation, by default a scratch directory.
# Every step continues on failure; the failures are the information.

JULIA_MODULE=${JULIA_MODULE:-lang/JuliaHPC/1.13.1-foss-2025a}
MPIWRAPPER_VERSION=${MPIWRAPPER_VERSION:-v2.11.0}
PREFIX=${PREFIX:-$(mktemp -d)/mpiwrapper}

section() { printf '\n==== %s ====\n' "$1"; }
show() { printf '\n$ %s\n' "$*"; "$@" 2>&1; }
julia_rank='using MPI; MPI.Init(); println("rank ", MPI.Comm_rank(MPI.COMM_WORLD), " of ", MPI.Comm_size(MPI.COMM_WORLD), " on ", gethostname()); MPI.Finalize()'
julia_stack='using MPI, HDF5, P4est, T8code; MPI.Init(); println("MPI: ", MPI.Get_library_version()); println("HDF5: ", HDF5.API.libhdf5, " parallel=", HDF5.has_parallel()); println("P4est uses MPI: ", P4est.uses_mpi()); println("T8code loaded"); MPI.Finalize()'
julia_parallel_hdf5='using MPI, HDF5
MPI.Init()
comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
path = joinpath(ENV["PROBE_DIR"], "parallel.h5")
h5open(path, "w", comm) do file
    dataset = create_dataset(file, "ranks", Int, (MPI.Comm_size(comm),))
    dataset[rank + 1] = rank
end
MPI.Barrier(comm)
rank == 0 && println("parallel HDF5 wrote ", h5read(path, "ranks"))
MPI.Finalize()'

section "modules"
module load "$JULIA_MODULE"
cmake_module=$({ module avail -t CMake; find_module CMake; } 2>&1 | grep -oE '[A-Za-z0-9_]+/CMake/[^ :]*GCCcore-14.2.0[^ :]*' | head -n 1)
if [ -z "$cmake_module" ]; then
    cmake_module=$({ module avail -t CMake; find_module CMake; } 2>&1 | grep -oE '[A-Za-z0-9_]+/CMake/[^ :]+' | head -n 1)
fi
echo "cmake module: ${cmake_module:-none, using cmake from PATH}"
show module list
show which mpicc mpifort mpiexec julia
echo "EBROOTOPENMPI=${EBROOTOPENMPI:-}"
echo "EBROOTJULIAHPC=${EBROOTJULIAHPC:-}"

section "preferences shipped with the Julia module"
show cat "${EBROOTJULIAHPC:-/nonexistent}/LocalPreferences.toml"
show cat "${EBROOTJULIAHPC:-/nonexistent}/Project.toml"

section "build MPIwrapper $MPIWRAPPER_VERSION against the system OpenMPI"
# CMake's module adds libraries that break Julia's package manager, so the
# build runs in a subshell and the module never reaches the Julia steps.
src=$(mktemp -d)/MPIwrapper
show git clone --quiet --depth 1 --branch "$MPIWRAPPER_VERSION" https://github.com/eschnett/MPIwrapper.git "$src"
(
    if [ -n "$cmake_module" ]; then module load "$cmake_module"; fi
    show which cmake
    show cmake --version
    show cmake -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DMPIEXEC_EXECUTABLE="${EBROOTOPENMPI:-/nonexistent}/bin/mpiexec"
    show cmake --build "$src/build" --parallel 8
    show cmake --install "$src/build"
)
show find "$PREFIX" -type f
wrapper_lib=$(find "$PREFIX" -name 'libmpiwrapper.so' | head -n 1)
wrapper_exec=$(find "$PREFIX/bin" -name 'mpiwrapper*exec' | head -n 1)
printf '\n$ ldd libmpiwrapper.so | mpi\n'
ldd "$wrapper_lib" 2>&1 | grep -iE 'mpi|open-pal|not found'

export MPITRAMPOLINE_LIB="$wrapper_lib"
export MPITRAMPOLINE_MPIEXEC="$wrapper_exec"
echo "MPITRAMPOLINE_LIB=$MPITRAMPOLINE_LIB"
echo "MPITRAMPOLINE_MPIEXEC=$MPITRAMPOLINE_MPIEXEC"

section "fresh project on MPItrampoline, module environment untouched"
tmp=$(mktemp -d)
export PROBE_DIR=$tmp
echo "project $tmp"
show julia --project="$tmp" -e 'using Pkg; Pkg.add("MPIPreferences"); using MPIPreferences; MPIPreferences.use_jll_binary("MPItrampoline_jll"; export_prefs = false)'
show cat "$tmp/LocalPreferences.toml"
show julia --project="$tmp" -e 'using Pkg; Pkg.add(["MPI", "HDF5", "P4est", "T8code"])'
show julia --project="$tmp" -e 'using MPI; MPI.versioninfo()'
show julia --project="$tmp" -e "$julia_stack"

section "two ranks through the system mpiexec and through the trampoline mpiexec"
show "${EBROOTOPENMPI:-/nonexistent}/bin/mpiexec" -n 2 julia --project="$tmp" -e "$julia_rank"
show "$MPITRAMPOLINE_MPIEXEC" -n 2 julia --project="$tmp" -e "$julia_rank"

section "parallel HDF5 through the trampoline"
show "${EBROOTOPENMPI:-/nonexistent}/bin/mpiexec" -n 2 julia --project="$tmp" -e "$julia_parallel_hdf5"

section "done"
echo "MPIwrapper kept at $PREFIX, project kept at $tmp"
