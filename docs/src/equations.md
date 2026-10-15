# Equations and materials

```@meta
CurrentModule = TrixiMaxwell
```

## Curl equations and normalization

[`MaxwellEquations3D`](@ref) defines the physical fields and the optional state
components. In the physical region, the electric-field equation can include
Ohmic loss, an impressed current and polarization currents. The magnetic
field is non-dispersive in the implemented material models.

```@docs
MaxwellEquations3D
```

Choose a length scale ``L`` and electric-field scale ``E_0``. With SI quantities
on the right, the dimensionless variables are

```math
x = x_{\rm SI}/L,\qquad t = c_0 t_{\rm SI}/L,\qquad
E = E_{\rm SI}/E_0,\qquad H = Z_0 H_{\rm SI}/E_0.
```

Thus vacuum has ``\epsilon=\mu=c=Z=1``. In a nondispersive material,

```math
c=(\epsilon\mu)^{-1/2},\qquad Z=(\mu/\epsilon)^{1/2},\qquad Y=1/Z.
```

Conductivity becomes ``\sigma=\sigma_{\rm SI}Z_0L`` and an angular frequency
becomes ``\omega=\omega_{\rm SI}L/c_0``. Ordinary frequencies used by signals
and transforms obey ``\omega=2\pi f``.

The code evolves the curl system without an additional charge-density equation
or divergence-cleaning field. The diagnostics measure elementwise divergences
of ``E`` and ``H``; they do not enforce the Gauss constraints.

### PEC cavity example

The cavity example shows the coupled electric and magnetic TM-mode fields. Its
analytical reference is discussed under [Diagnostics and validation](@ref).

![PEC cavity fields](assets/figures/cavity_mode.png)

## State layout and static materials

The state starts with `(Ex, Ey, Ez, Hx, Hy, Hz)`. Its remaining blocks are:

| Model option | Additional components |
|:--|:--|
| `Heterogeneous()` | `epsilon`, `mu`, `sigma`, then the parameters of each pole |
| Each Drude pole | Three polarization-current components |
| Each Lorentz pole | Three polarization and three current components |
| `UPML()` | Six auxiliary components `(px, py, pz, qx, qy, qz)` |

`Homogeneous()` reads material parameters from the equations object.
`Heterogeneous()` reads them from the state. They have zero flux and zero
source, so their values remain constant in time on a fixed mesh. `set_materials!`
assigns the same material to every node of an element; material interfaces must
therefore follow element faces. These passive parameters are distinct from the
dynamical polarization and PML components, which have zero flux but nonzero
sources.

```@docs
Material
set_materials!
permittivity
```

### Fresnel interface example

The pulse splits into reflected and transmitted waves at the material interface. The dashed line marks the permittivity jump.

![Fresnel interface](assets/figures/fresnel.png)

### Dielectric sphere example

A plane-wave pulse interacts with a dielectric sphere. The outline marks its material interface.

![Dielectric sphere](assets/figures/dielectric_sphere.png)

## Conductivity and dispersion

`epsilon` denotes ``\epsilon_\infty`` when dispersion is enabled. Each pole
contributes its current to Ampere's law; the pole parameters can differ between
elements. The constructor fixes the number of poles; an element contains fewer
active poles when the remaining ones are inactive, with zero plasma frequency
for a Drude pole or zero strength for a Lorentz pole.

```@docs
source_terms_conductivity
Dispersive
DrudePole
LorentzPole
source_terms_dispersive
```

Material parameters alone do not install a source term. Select
`source_terms_conductivity` or `source_terms_dispersive` in the semidiscretization,
or combine them with [`CombinedSourceTerms`](@ref). The dipole source already
includes conductivity; do not add the same conductivity source a second time.

For example:

```jldoctest
julia> using TrixiMaxwell

julia> equations = MaxwellEquations3D(epsilon = 4.0);

julia> speed_of_light(equations), impedance(equations)
(0.5, 0.5)
```

## Frequency-domain material reference

The time-domain pole equations correspond to the complex permittivity evaluated
by `relative_permittivity`. This reference uses ``e^{-i\omega t}``, for which a
passive material has positive imaginary permittivity. It is used when comparing
simulations to the Mie and slab formulas.

```@docs
relative_permittivity
normalized_angular_frequency
material_gold
```

The gold preset is a fitted Drude–Lorentz model over the wavelength range stated
in its docstring. It is a material model within that range, rather than a general
optical model of gold at arbitrary frequencies.
