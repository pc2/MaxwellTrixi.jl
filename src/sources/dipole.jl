@doc raw"""
    HertzianDipole(position, moment, width, signal)

Electric dipole ``p(t) = s(t) \, p_0`` at `position` with `moment` ``p_0`` and
time `signal` ``s``, regularized in space over
``G_w(x) = \exp(-|x - x_0|^2 / w^2) / (\pi^{3/2} w^3)``. Passed as `source_terms`
it drives Ampère's law with the current density
```math
J_{\mathrm{src}}(x,t) = \dot s(t)\,p_0\,
    \frac{\exp(-|x-x_0|^2/w^2)}{\pi^{3/2}w^3}
```
and adds
the Ohmic loss of [`source_terms_conductivity`](@ref). The exact field of the
point dipole is [`HertzianDipoleField`](@ref).
"""
struct HertzianDipole{RealT <: Real, Signal}
    position::SVector{3, RealT}
    moment::SVector{3, RealT}
    width::RealT
    normalization::RealT
    signal::Signal
end

function HertzianDipole(position, moment, width, signal)
    x0, p0 = promote(SVector{3}(position), SVector{3}(moment))
    w = convert(eltype(x0), width)
    normalization = inv(sqrt(oftype(w, pi))^3 * w^3)
    return HertzianDipole(x0, p0, w, normalization, signal)
end

@inline function current_density(dipole::HertzianDipole, x, t)
    r2 = sum(abs2, x - dipole.position)
    amplitude = dipole.normalization * exp(-r2 / dipole.width^2)
    return signal_derivative(dipole.signal, t) * amplitude * dipole.moment
end

@inline function (dipole::HertzianDipole)(u, x, t, equations::MaxwellEquations3D)
    J = current_density(dipole, x, t)
    eps = permittivity(u, equations)
    source = vcat(-J / eps, zero(J), passive_flux(equations))
    return source + source_terms_conductivity(u, x, t, equations)
end

function Base.show(io::IO, dipole::HertzianDipole)
    print(io, "HertzianDipole(", dipole.position, ", ", dipole.moment, ", ", dipole.width,
          ", ", dipole.signal, ")")
end

@doc raw"""
    HertzianDipoleField(position, moment, signal)
    HertzianDipoleField(dipole::HertzianDipole, equations)

Exact field of the point dipole ``p(t) = s(t) \, p_0`` in a homogeneous,
lossless, nondispersive background material, with ``R = |x - x_0|``,
``\hat r = (x - x_0) / R`` and all moments taken at the retarded time ``t - R / c``:
```math
E = \frac{1}{4 \pi \epsilon} \left( \frac{3 \hat r (\hat r \cdot p) - p}{R^3}
  + \frac{3 \hat r (\hat r \cdot \dot p) - \dot p}{c R^2}
  + \frac{\hat r \times (\hat r \times \ddot p)}{c^2 R} \right), \quad
H = \frac{1}{4 \pi} \left( \frac{\dot p \times \hat r}{R^2}
  + \frac{\ddot p \times \hat r}{c R} \right).
```
Outside the source region ``R \gg w`` the regularized [`HertzianDipole`](@ref)
radiates like a point dipole whose signal is ``s`` convolved with the line-of-sight
profile of ``G_w``, a Gaussian of width ``w / c``. For a [`GaussianPulse`](@ref) of
width ``a`` this is a Gaussian pulse of width ``\sqrt{a^2 + (w/c)^2}`` with the
moment scaled by ``a / \sqrt{a^2 + (w/c)^2}``, which the second constructor applies.
"""
struct HertzianDipoleField{RealT <: Real, Signal} <: AbstractIncidentField
    position::SVector{3, RealT}
    moment::SVector{3, RealT}
    signal::Signal
end

function HertzianDipoleField(position, moment, signal)
    x0, p0 = promote(SVector{3}(position), SVector{3}(moment))
    return HertzianDipoleField(x0, p0, signal)
end

function HertzianDipoleField(dipole::HertzianDipole{<:Real, <:GaussianPulse},
                             equations::MaxwellEquations3D)
    (; width, delay) = dipole.signal
    c = equations.speed_of_light
    smoothed_width = sqrt(width^2 + (dipole.width / c)^2)
    return HertzianDipoleField(dipole.position, dipole.moment * width / smoothed_width,
                               GaussianPulse(smoothed_width; delay))
end

function HertzianDipoleField(dipole::HertzianDipole, equations::MaxwellEquations3D)
    throw(ArgumentError("the exterior field of a regularized dipole is available for GaussianPulse signals only; construct a point dipole field from position, moment and signal instead"))
end

@inline function (field::HertzianDipoleField)(x, t, equations::MaxwellEquations3D)
    c = equations.speed_of_light
    eps = equations.epsilon

    r = x - field.position
    R = norm(r)
    r_hat = r / R
    tau = t - R / c
    p = field.signal(tau) * field.moment
    dp = signal_derivative(field.signal, tau) * field.moment
    ddp = signal_second_derivative(field.signal, tau) * field.moment

    inv_4pi = inv(4 * oftype(R, pi))
    E = inv_4pi / eps * ((3 * dot(r_hat, p) * r_hat - p) / R^3 +
         (3 * dot(r_hat, dp) * r_hat - dp) / (c * R^2) +
         cross(r_hat, cross(r_hat, ddp)) / (c^2 * R))
    H = inv_4pi * (cross(dp, r_hat) / R^2 + cross(ddp, r_hat) / (c * R))
    return with_passive_defaults(vcat(E, H), equations)
end
