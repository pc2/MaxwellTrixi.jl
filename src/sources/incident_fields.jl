"""
    AbstractIncidentField

Analytic free-space solution `field(x, t, equations)` in the background material
of the equations, returned with the default material components. Usable as
initial condition, in [`BoundaryConditionIncidentField`](@ref) and in
[`TotalFieldScatteredField`](@ref). Two fields are superposed with `+`.
"""
abstract type AbstractIncidentField end

@doc raw"""
    PlaneWave(direction, polarization, signal)

Plane wave ``E = s(t - \hat k \cdot x / c) \, e``, ``H = Y \, \hat k \times E`` with
the unit propagation direction ``\hat k``, the polarization vector ``e`` (amplitude
included, orthogonal to ``\hat k``) and a time signal such as [`GaussianPulse`](@ref).
Requires a homogeneous, lossless, nondispersive background material; ``c`` and
``Y`` are taken from the equations object.
"""
struct PlaneWave{RealT <: Real, Signal} <: AbstractIncidentField
    direction::SVector{3, RealT}
    polarization::SVector{3, RealT}
    signal::Signal
end

function PlaneWave(direction, polarization, signal)
    k = SVector{3}(direction) / norm(direction)
    e = SVector{3}(polarization)
    if abs(dot(k, e)) > sqrt(eps(eltype(k))) * norm(e)
        throw(ArgumentError("polarization $polarization is not orthogonal to direction $direction"))
    end
    k, e = promote(k, e)
    return PlaneWave(k, e, signal)
end

@inline function (wave::PlaneWave)(x, t, equations::MaxwellEquations3D)
    tau = t - dot(wave.direction, x) / equations.speed_of_light
    E = wave.signal(tau) * wave.polarization
    H = equations.admittance * cross(wave.direction, E)
    return with_passive_defaults(vcat(E, H), equations)
end

function Base.show(io::IO, wave::PlaneWave)
    print(io, "PlaneWave(", wave.direction, ", ", wave.polarization, ", ", wave.signal, ")")
end

struct SuperposedIncidentFields{A, B} <: AbstractIncidentField
    first::A
    second::B
end

Base.:+(a::AbstractIncidentField, b::AbstractIncidentField) = SuperposedIncidentFields(a, b)

@inline function (fields::SuperposedIncidentFields)(x, t, equations::MaxwellEquations3D)
    u_a = fields.first(x, t, equations)
    u_b = fields.second(x, t, equations)
    E = electric_field(u_a) + electric_field(u_b)
    H = magnetic_field(u_a) + magnetic_field(u_b)
    return with_passive_defaults(vcat(E, H), equations)
end

"""
    initial_condition_zero(x, t, equations::MaxwellEquations3D)

Zero fields with the default material of the equations.
"""
function initial_condition_zero(x, t, equations::MaxwellEquations3D)
    return with_passive_defaults(zero(SVector{6, eltype(x)}), equations)
end
