#!/usr/bin/env bash
# Builds MPIwrapper, the library MPItrampoline forwards to, against the
# loaded OpenMPI module into <prefix>. Skipped when <prefix> already holds a
# build for this version and OpenMPI.
#
#   hpc/install_mpiwrapper.sh <prefix>
set -euo pipefail

prefix=${1:?usage: install_mpiwrapper.sh <prefix>}
version=${MPIWRAPPER_VERSION:-v2.11.0}
openmpi=${EBROOTOPENMPI:?load an OpenMPI module first}
marker="$prefix/VERSION"
wanted="$version $openmpi"

if [ -f "$marker" ] && [ "$(cat "$marker")" = "$wanted" ] && ls "$prefix"/lib*/libmpiwrapper.so > /dev/null 2>&1; then
    echo "MPIwrapper $version for $openmpi is in $prefix"
    exit 0
fi

# CMake's module adds libraries that break Julia's package manager, so it is
# loaded in a subshell only.
cmake_module=$({ module avail -t CMake; find_module CMake; } 2>&1 | grep -oE "[A-Za-z0-9_]+/CMake/[^ :]*GCCcore-${EBVERSIONGCCCORE:-14.2.0}[^ :]*" | head -n 1 || true)
source=$(mktemp -d)
git clone --quiet --depth 1 --branch "$version" https://github.com/eschnett/MPIwrapper.git "$source/MPIwrapper"
(
    if [ -n "$cmake_module" ]; then module load "$cmake_module"; fi
    cmake -S "$source/MPIwrapper" -B "$source/build" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$prefix" -DMPIEXEC_EXECUTABLE="$openmpi/bin/mpiexec"
    cmake --build "$source/build" --parallel "${SLURM_CPUS_PER_TASK:-4}"
    cmake --install "$source/build"
)
rm -rf "$source"
echo "$wanted" > "$marker"
echo "MPIwrapper $version built against $openmpi into $prefix"
