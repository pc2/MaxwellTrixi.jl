window.BENCHMARK_DATA = {
  "lastUpdate": 1792574927801,
  "repoUrl": "https://github.com/pc2/MaxwellTrixi.jl",
  "entries": {
    "HPC validation": [
      {
        "commit": {
          "author": {
            "name": "Gerrit Pape",
            "username": "papeg",
            "email": "gerrit.pape@uni-paderborn.de"
          },
          "committer": {
            "name": "Gerrit Pape",
            "username": "papeg",
            "email": "gerrit.pape@uni-paderborn.de"
          },
          "id": "79c7ef92f37f050e867b9819b656ec2d233ea75d",
          "message": "use github-action-benchmark",
          "timestamp": "2026-10-21T07:05:42Z",
          "url": "https://github.com/pc2/MaxwellTrixi.jl/commit/79c7ef92f37f050e867b9819b656ec2d233ea75d"
        },
        "date": 1792574926018,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "dielectric_sphere/default PID",
            "value": 0.000020030941046367272,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "dielectric_sphere/default time per DOF per rhs",
            "value": 0.00001800548552412286,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/default PID",
            "value": 0.000012018278027592357,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/default time per DOF per rhs",
            "value": 0.000010027282705911094,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/default scattering",
            "value": 0.01820039097823757,
            "unit": "relative error",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/default absorption fraction",
            "value": 0.02688432738256935,
            "unit": "ratio",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie_drude/default PID",
            "value": 0.00002217626509973628,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie_drude/default time per DOF per rhs",
            "value": 0.000018219780415180636,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie_drude/default extinction",
            "value": 0.02736804465207736,
            "unit": "relative error",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie_drude/default absorption",
            "value": 0.10719147068715883,
            "unit": "relative error",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "pec_sphere/default PID",
            "value": 0.00002625259239073538,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "pec_sphere/default time per DOF per rhs",
            "value": 0.00002477146780290585,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "slab/default PID",
            "value": 0.000021057958142442352,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "slab/default time per DOF per rhs",
            "value": 0.000018106150368637212,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "slab/default transmittance",
            "value": 0.003096097746362103,
            "unit": "absolute error",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "slab/default reflectance",
            "value": 0.0001936811346098799,
            "unit": "absolute error",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "slab_dispersive/default PID",
            "value": 0.00005896782447477059,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "slab_dispersive/default time per DOF per rhs",
            "value": 0.000049268317917838956,
            "unit": "s",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "slab_dispersive/default transmittance",
            "value": 0.0003827266640420435,
            "unit": "absolute error",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "slab_dispersive/default reflectance",
            "value": 0.000615623587242653,
            "unit": "absolute error",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "slab_dispersive/default transmittance plus reflectance",
            "value": 0.6913849296088684,
            "unit": "ratio",
            "extra": "threads=32, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          }
        ]
      }
    ],
    "HPC scaling": [
      {
        "commit": {
          "author": {
            "name": "Gerrit Pape",
            "username": "papeg",
            "email": "gerrit.pape@uni-paderborn.de"
          },
          "committer": {
            "name": "Gerrit Pape",
            "username": "papeg",
            "email": "gerrit.pape@uni-paderborn.de"
          },
          "id": "79c7ef92f37f050e867b9819b656ec2d233ea75d",
          "message": "use github-action-benchmark",
          "timestamp": "2026-10-21T07:05:42Z",
          "url": "https://github.com/pc2/MaxwellTrixi.jl/commit/79c7ef92f37f050e867b9819b656ec2d233ea75d"
        },
        "date": 1792574927778,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "mie/t1 PID",
            "value": 3.2646511654629406e-7,
            "unit": "s",
            "extra": "threads=1, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/t1 time per DOF per rhs",
            "value": 2.7621423268809246e-7,
            "unit": "s",
            "extra": "threads=1, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/t16 PID",
            "value": 0.000007410802533423603,
            "unit": "s",
            "extra": "threads=16, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/t16 time per DOF per rhs",
            "value": 0.000006309642607294822,
            "unit": "s",
            "extra": "threads=16, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/t2 PID",
            "value": 7.193634733997237e-7,
            "unit": "s",
            "extra": "threads=2, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/t2 time per DOF per rhs",
            "value": 6.030521161683484e-7,
            "unit": "s",
            "extra": "threads=2, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/t4 PID",
            "value": 0.0000017117470030540204,
            "unit": "s",
            "extra": "threads=4, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/t4 time per DOF per rhs",
            "value": 0.0000014414592568055617,
            "unit": "s",
            "extra": "threads=4, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/t8 PID",
            "value": 0.0000039962669015240435,
            "unit": "s",
            "extra": "threads=8, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          },
          {
            "name": "mie/t8 time per DOF per rhs",
            "value": 0.0000034638723538447,
            "unit": "s",
            "extra": "threads=8, status=pass, https://git.uni-paderborn.de/pc2-ci/julia/MaxwellTrixi.jl/-/pipelines/155912"
          }
        ]
      }
    ]
  }
}