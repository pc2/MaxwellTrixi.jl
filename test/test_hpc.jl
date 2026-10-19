module TestHPC

using Test
using TestReports
using Trixi
using MaxwellTrixi
using DelimitedFiles: writedlm

# Full-resolution simulations for the cluster. TRIXI_TEST=hpc_<case> selects
# the case and HPC_VARIANT one of its variants: `short` only exercises the
# mechanics, t<n> runs the default setup on n threads. Each run writes
# junit.xml with the test results, metrics.txt in OpenMetrics format and
# data.csv to <case>/<variant>/ below HPC_RESULTS_DIR, by default results/.

const CASE = chopprefix(ENV["TRIXI_TEST"], "hpc_")
const VARIANT = get(ENV, "HPC_VARIANT", "default")
const RESULTS_DIR = joinpath(get(ENV, "HPC_RESULTS_DIR", pkgdir(MaxwellTrixi, "results")),
                             CASE, VARIANT)
const EXAMPLES_DIR = pkgdir(MaxwellTrixi, "examples")
const MAXITERS = 10_000_000

# Overrides for trixi_include per case and variant.
const VARIANTS = Dict("mie" => Dict("h30" => (; size_factor = 3.0),
                           "h15" => (; size_factor = 1.5),
                           "h10" => (; size_factor = 1.0),
                           "p2" => (; polydeg = 2),
                           "p4" => (; polydeg = 4)),
                      "slab" => Dict("n14" => (; cells_per_dimension = (2, 2, 14)),
                           "n56" => (; cells_per_dimension = (2, 2, 56)),
                           "p2" => (; polydeg = 2),
                           "p4" => (; polydeg = 4)))

function overrides(case, variant)
    variant == "default" && return (;)
    variant == "short" && return (; tspan = (0.0, 0.5))
    occursin(r"^t\d+$", variant) && return (;)
    return VARIANTS[case][variant]
end

function repository_commit()
    for key in ("CI_COMMIT_SHA", "GITHUB_SHA")
        haskey(ENV, key) && return ENV[key]
    end
    try
        return readchomp(`git -C $(pkgdir(MaxwellTrixi)) rev-parse HEAD`)
    catch
        return "unknown"
    end
end

const LABELS = (; case = CASE, variant = VARIANT, threads = Threads.nthreads(), ranks = 1,
                commit = repository_commit(), trixi = string(pkgversion(Trixi)),
                julia = string(VERSION), pipeline = get(ENV, "CI_PIPELINE_ID", ""),
                job = get(ENV, "CI_JOB_ID", ""), slurm_job = get(ENV, "SLURM_JOB_ID", ""))
const METRICS = String[]

# One OpenMetrics line per value; the labels identify the run.
function record(name, value; labels...)
    text = join(("$key=\"$label\"" for (key, label) in pairs(merge(LABELS, (; labels...)))),
                ",")
    push!(METRICS, "maxwelltrixi_$name{$text} $value")
end

# Trixi's performance indicators from its timer: time per DOF per rhs from the
# rhs section, the PID from the time measured in all sections but the analysis,
# a few percent below the wall time of the solve.
function record_performance(semi, sol, wall_time)
    timing = Trixi.TimerOutputs.todict(Trixi.timer())
    sections = timing["inner_timers"]
    rhs = haskey(sections, "rhs!") ? sections["rhs!"] : sections["rhs_hyperbolic!"]
    calls = rhs["n_calls"]
    rhs_time = rhs["time_ns"] / 1e9
    analysis_time = get(sections, "analyze solution", Dict("time_ns" => 0))["time_ns"] / 1e9
    solve_time = timing["total_time_ns"] / 1e9 - analysis_time
    ndofs = Trixi.ndofs(semi)
    threads = Threads.nthreads()
    record("ndofs", ndofs)
    record("steps", sol.stats.naccept)
    record("rhs_calls", calls)
    record("rhs_seconds", rhs_time)
    record("solve_seconds", solve_time)
    record("wall_seconds", wall_time)
    record("time_per_dof_per_rhs_seconds", rhs_time * threads / (ndofs * calls))
    record("pid_seconds", solve_time * threads / (ndofs * calls))
end

function write_data(columns)
    mkpath(RESULTS_DIR)
    names = reshape([first(column) for column in columns], 1, :)
    open(joinpath(RESULTS_DIR, "data.csv"), "w") do io
        writedlm(io, [names; reduce(hcat, last.(columns))], ',')
    end
end

refractive_index(material, frequency) = sqrt(relative_permittivity(material, frequency))

# Cross sections of a sphere against the Mie series, relative tolerances per
# quantity; absorption_fraction bounds spurious absorption of a lossless sphere.
function check_cross_sections(sigma, radius, material; frequency_min = 0.0,
                              scattering = nothing, extinction = nothing,
                              absorption = nothing, absorption_fraction = nothing)
    frequencies = collect(sigma.frequencies)
    area = pi * radius^2
    reference = [mie_efficiencies(refractive_index(material, f), 2 * pi * f * radius)
                 for f in frequencies]
    columns = ["frequency" => frequencies]
    for quantity in (:scattering, :extinction, :absorption)
        push!(columns, string(quantity) => getfield(sigma, quantity))
        push!(columns,
              string(quantity, "_reference") => getfield.(reference, quantity) .* area)
    end
    write_data(columns)

    selected = findall(>=(frequency_min), frequencies)
    for (key, rtol) in (("scattering", scattering), ("extinction", extinction),
        ("absorption", absorption))
        rtol === nothing && continue
        simulated = getfield(sigma, Symbol(key))[selected]
        exact = getfield.(reference, Symbol(key))[selected] .* area
        for k in eachindex(selected)
            @test simulated[k]≈exact[k] rtol=rtol
        end
        record(key * "_relative_error", maximum(abs.(simulated .- exact) ./ abs.(exact)))
    end
    if absorption_fraction !== nothing
        fraction = maximum(abs.(sigma.absorption[selected]) ./
                           abs.(sigma.scattering[selected]))
        @test fraction < absorption_fraction
        record("absorption_fraction", fraction)
    end
end

# Transmittance and reflectance of a slab against the Airy formula.
function check_slab(frequencies, transmittance, reflectance, material, thickness;
                    transmittance_atol, reflectance_atol, power_balance = false)
    frequencies = collect(frequencies)
    airy = [slab_transmittance_reflectance(refractive_index(material, f), thickness, f)
            for f in frequencies]
    exact_transmittance = getfield.(airy, :transmittance)
    exact_reflectance = getfield.(airy, :reflectance)
    write_data(["frequency" => frequencies,
                   "transmittance" => transmittance,
                   "transmittance_reference" => exact_transmittance,
                   "reflectance" => reflectance,
                   "reflectance_reference" => exact_reflectance])

    for k in eachindex(frequencies)
        @test transmittance[k]≈exact_transmittance[k] atol=transmittance_atol
        @test reflectance[k]≈exact_reflectance[k] atol=reflectance_atol
    end
    record("transmittance_absolute_error",
           maximum(abs.(transmittance .- exact_transmittance)))
    record("reflectance_absolute_error", maximum(abs.(reflectance .- exact_reflectance)))
    if power_balance
        @test all(transmittance .+ reflectance .< 1)
        record("transmittance_plus_reflectance", maximum(transmittance .+ reflectance))
    end
end

# The checks use the variables of the elixir after it ran in this module.
const CASES = Dict("mie" => (elixir = "dgmulti_3d/elixir_maxwell_3d_mie.jl",
                    check = () -> check_cross_sections(sigma, sphere_radius,
                                                       sphere_material;
                                                       frequency_min = 0.3,
                                                       scattering = 0.02,
                                                       absorption_fraction = 0.03)),
                   # tolerances of the dispersive spheres are provisional until their first full runs
                   "mie_drude" => (elixir = "dgmulti_3d/elixir_maxwell_3d_mie_drude.jl",
                    check = () -> check_cross_sections(sigma, sphere_radius,
                                                       sphere_material;
                                                       frequency_min = 0.3,
                                                       extinction = 0.05,
                                                       absorption = 0.1)),
                   "gold_nanosphere" =>
                       (elixir = "dgmulti_3d/elixir_maxwell_3d_gold_nanosphere.jl",
                        check = () -> check_cross_sections(sigma,
                                                           sphere_radius,
                                                           sphere_material;
                                                           extinction = 0.1)),
                   "slab" => (elixir = "dgmulti_3d/elixir_maxwell_3d_slab.jl",
                    check = () -> check_slab(frequencies, transmittance,
                                             reflectance, slab_material,
                                             slab_thickness;
                                             transmittance_atol = 5e-3,
                                             reflectance_atol = 1e-3)),
                   "slab_dispersive" =>
                       (elixir = "dgmulti_3d/elixir_maxwell_3d_slab_dispersive.jl",
                        check = () -> check_slab(frequencies, transmittance,
                                                 reflectance, slab_material,
                                                 slab_thickness;
                                                 transmittance_atol = 2e-3,
                                                 reflectance_atol = 2e-3,
                                                 power_balance = true)),
                   "dielectric_sphere" =>
                       (elixir = "dgmulti_3d/elixir_maxwell_3d_dielectric_sphere.jl",
                        check = () -> nothing),
                   "pec_sphere" => (elixir = "dgmulti_3d/elixir_maxwell_3d_pec_sphere.jl",
                    check = () -> nothing))

haskey(CASES, CASE) || error("unknown HPC case $CASE")
elixir = joinpath(EXAMPLES_DIR, CASES[CASE].elixir)
println("HPC case $CASE, variant $VARIANT, $(Threads.nthreads()) threads: $elixir")
wall_time = @elapsed trixi_include(@__MODULE__, elixir; maxiters = MAXITERS,
                                   overrides(CASE, VARIANT)...)

report_set = @testset ReportingTestSet "hpc $CASE $VARIANT" begin
    @testset "checks" begin
        @test string(sol.retcode) == "Success"
        VARIANT == "short" || CASES[CASE].check()
    end
    @testset "performance" begin
        record_performance(semi, sol, wall_time)
    end
end

mkpath(RESULTS_DIR)
write(joinpath(RESULTS_DIR, "metrics.txt"), join(METRICS, '\n') * '\n')
open(joinpath(RESULTS_DIR, "junit.xml"), "w") do io
    print(io, report(report_set))
end
println("results in $RESULTS_DIR")

# a reporting testset is not counted by its parent, so its outcome is asserted here
@testset "hpc $CASE $VARIANT passed" begin
    @test !any_problems(report_set)
end

end # module
