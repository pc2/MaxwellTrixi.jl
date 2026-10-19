# Cluster files

Used by `.gitlab-ci.yml` on the Otus Slurm runner, see "Cluster runs" in the
documentation's "Building and publishing" page.

- `preferences/Project.toml`: put on `JULIA_LOAD_PATH` by every job; routes
  MPI through MPItrampoline.
- `install_mpiwrapper.sh`: builds MPIwrapper against the loaded OpenMPI
  module into the depot root; run by `prepare`, skipped when present.
- `probe_sandbox.sh`: runs the steps of a case job by hand on a login node
  against the CI depot, to check changes before a pipeline.
- `probe_mpi.sh`, `probe_mpitrampoline.sh`: the diagnostics that established
  the MPI setup; rerun them when the Julia or OpenMPI module changes.

The cases themselves are in `test/test_hpc.jl`.
