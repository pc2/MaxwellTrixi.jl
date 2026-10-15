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
