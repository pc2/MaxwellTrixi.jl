# Building and publishing

## Local documentation

From the repository root:

```sh
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --threads=1 --project=docs docs/make.jl
python3 -m http.server 8000 --bind 127.0.0.1 --directory docs/build
```

Open <http://127.0.0.1:8000>. The build checks docstrings, cross-references and
short doctests. It does not run the numerical test suite or simulations.

To include the animations, generate them first:

```sh
julia --project=utils/visualize -e 'using Pkg; Pkg.instantiate()'
julia --threads=1 --project=utils/visualize utils/visualize/make_all.jl --video
julia --threads=1 --project=docs docs/make.jl
```

Each example uses its committed PNG from `docs/figures/` unless a matching MP4
is present in `docs/videos/`. The build includes whichever is available.
PNG figures are committed; videos, documentation output and manifests are ignored.

## Extending the docs

- Edit the relevant page in `docs/src/`. To add a page, create a Markdown file
  there and add it to the `pages` list in `docs/make.jl`.
- Keep API definitions and formulas in their source docstrings, and include them
  with an `@docs` block. Use the surrounding prose for examples and explanations.
- Add a figure on its own line as `![Description](assets/figures/name.png)` and commit
  `docs/figures/name.png`, with `name` made of lowercase letters, digits and
  underscores. An optional `docs/videos/name.mp4` replaces it at build time. See
  [Figures and videos](@ref) for the rendering scripts.

Run the documentation build above to check the result.

## GitHub Actions and Pages

`.github/workflows/docs.yml` builds the documentation with committed figures on
pull requests and pushes to `main`, without running simulations. Pull requests
upload the site as an artifact; pushes to `main` also publish it with GitHub Pages.

To include videos, choose **Actions → Documentation → Run workflow** and enable
**Render and include all example videos** (`render_videos`). This runs the ten
visualization jobs, reusing cached videos when their inputs match, then builds
the site with those videos. Rendering uses Xvfb and software OpenGL and
does not need a GPU. Manual runs from `main` also publish the site. Subsequent
ordinary builds use figures again.

Enable **Settings → Pages → Build and deployment → Source: GitHub Actions** in
the repository once, then push the workflow and documentation sources.

## Cluster runs

Long simulations run on the Otus cluster through the GitLab mirror
`git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl` and its Slurm runner. The
cases are testsets in `test/test_hpc.jl`: full-resolution elixirs with the
reference checks of the test suite, selected by `TRIXI_TEST=hpc_<case>`, and
`HPC_VARIANT` for a thread count such as `t8` or `short`, both running a
short time span without the checks. Each run writes
`results/<case>/<variant>/`: `junit.xml` with one entry per check,
`metrics.txt` with the errors against the references and Trixi's performance
indicators in OpenMetrics format, and `data.csv` with the spectrum next to its
reference. Locally, from the repository root:

```sh
TRIXI_TEST=hpc_mie julia --project -e 'using Pkg; Pkg.test()'
```

The JUnit file comes from TestReports.jl inside the test process; the test
project pins it to its fix for Julia 1.13 until the 1.4.1 release.

`.gitlab-ci.yml` runs `prepare`, which fills the Julia depot, builds the
MPI wrapper and downloads the meshes, then one Slurm job per case.
`FAMILIES` selects `validation` or `scaling`. `SCHEDULER_BASE` carries the
account, partition and memory, each job adds its walltime and cores. Pipelines run only when started
from GitHub or from the GitLab UI, never on pushes to the mirror. The GitLab
project needs the CI/CD variable `CI_DEPOT_ROOT`, an absolute path on the
parallel file system.

**Actions → HPC → Run workflow** waits until the pull mirror has fetched the
commit, starts the pipeline with the chosen families and waits for it; after
5.5 hours, the
limit of a GitHub job, it hands over to a new run of itself. While waiting
it keeps one check run per GitLab job on the commit up to date, plus one for
the pipeline with the job table, so the Checks tab shows the Slurm jobs live.
When the pipeline has finished, the run downloads the artifacts and publishes
a check run from the JUnit files, a results table in the run summary, the raw
results as a run artifact and the commit status `gitlab/hpc` linking to the
pipeline. `ci/results.sh benchmark` then turns the `metrics.txt` files into
the JSON of [github-action-benchmark](https://github.com/benchmark-action/github-action-benchmark),
one entry per case, variant and quantity, and the action records them: a run
on `main` appends them to `bench/data.js` on the branch `hpc-results`, which
the action creates on first use, and the documentation build copies that
directory into the site. The page [Validation and performance](@ref) draws
its charts from `bench/data.js`, `docs/src/assets/hpc.js` reads it in the
browser, and the action's own dashboard stays available under `bench/`. The suite `HPC validation` holds the
reference errors and the performance indicators of the full cases, `HPC
scaling` the indicators of the timing variants. The action also compares
every quantity with its previous value on `main`: an increase beyond
`ALERT_THRESHOLD`, 115% by default, is reported in the run summary and as a
comment on the commit, beyond `FAIL_THRESHOLD`, 150% by default, it fails
the run. Both are GitHub variables, as is `BENCHMARK_BRANCH`.

This is also how a pull request is tested: start the workflow by hand on the
branch of the pull request. The check runs attach to its head commit and
appear in the pull request, and the comparison with the latest `main` run is
posted as a comment on that commit, which the pull request shows in its
timeline; nothing is appended to the history. The cluster runs the branch's
code under the account of the runner, so a run stays a deliberate act by a
maintainer, and branches from forks cannot be run this way, since the pull
mirror only fetches this repository.
`ci/gitlab_pipeline.sh` holds the GitLab calls and works by hand with the
same variables.

A weekly run is prepared but disabled: the `schedule` block in
`.github/workflows/hpc.yml` is commented out. Enabling it runs the
`validation` family on `main` every Monday at 03:00 UTC. GitHub suspends
scheduled workflows after 60 days without activity in the repository and
shows a notice to re-enable them.

### Setup

On the GitLab project, once:

1. **Settings → Repository → Mirroring repositories**: pull from the GitHub
   repository. Runs from feature branches need the mirror to fetch all
   branches, not only protected ones.
2. **Settings → Access tokens**: add a token with role Reporter and the scope
   `read_api`. It polls the pipeline and downloads artifacts, and can do
   nothing else.
3. **Settings → CI/CD → Pipeline trigger tokens**: add a token. It can only
   start pipelines.
4. **Settings → CI/CD → Variables**: add `CI_DEPOT_ROOT` with an absolute
   path on the parallel file system, for example
   `/scratch/<project>/<user>/MaxwellTrixi-ci`. The runner does not
   expand `$PC2PFS` here. Leave "Protect variable" off.
5. Note the project ID from the project overview page (three circles in the top right).

On GitHub, from the repository, each `gh secret set` prompts for its value:

```sh
gh secret set GITLAB_TOKEN
gh secret set GITLAB_TRIGGER_TOKEN
gh variable set GITLAB_PROJECT_ID --body <id>
```

`GITLAB_HOST` defaults to `git.uni-paderborn.de` and can be overridden as a
variable. Nothing GitHub-related is stored on GitLab.

MPI on the cluster goes through MPItrampoline: `prepare` builds MPIwrapper
against the OpenMPI of the Julia module into `CI_DEPOT_ROOT`, and
`hpc/preferences/Project.toml`, placed on `JULIA_LOAD_PATH` ahead of the
module, points MPIPreferences at MPItrampoline. MPI.jl, HDF5.jl, P4est.jl
and T8code.jl then all forward to the system OpenMPI with its network
stack, and no bundled OpenMPI is loaded. Without this, the module's own
system-MPI setting makes HDF5_jll load a second, bundled OpenMPI with the
same library names, which fails on Otus. `hpc/probe_mpi.sh` and
`hpc/probe_mpitrampoline.sh` are the diagnostics that established this.

The pull mirror's schedule is set for the whole GitLab instance, not per
project. To skip the wait, set the GitHub variable `GITLAB_MIRROR` to
`push`: the workflow then pushes the commit itself. This needs the scope
`write_repository` on the token, role Developer, and under
**Settings → Repository → Protected branches** permission for Developers to
push and force push `main`.

To run the cluster side alone, start a pipeline under **Build → Pipelines →
New pipeline** with the variable `FAMILIES` once the mirror has fetched the
commit. The full loop from GitHub:

```sh
gh workflow run hpc.yml -f families=validation
gh run watch
```
