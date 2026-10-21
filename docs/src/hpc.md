# Validation and performance

Results of the full-resolution runs on the cluster for every run on `main`,
as [github-action-benchmark](https://github.com/benchmark-action/github-action-benchmark)
records them on the branch `hpc-results`. See [Building and publishing](@ref)
for how the runs are started and recorded.

The accuracy charts show the errors of the reference checks of each case,
the performance charts the chosen indicator per thread count over commits,
and the scaling chart the latest run of the timing variants; since both
indicators are scaled by the thread count, a flat line means perfect
scaling. Hover or use the arrow keys on a chart for the values at one run,
and open its data table for all of them. The action's own dashboard, one
chart per quantity, is at [bench](https://pc2.github.io/MaxwellTrixi.jl/bench/).

```@raw html
<link rel="stylesheet" href="../assets/hpc.css">
<div class="viz-root" id="hpc">
  <div class="viz-filters">
    <label>Case <select id="hpc-case"></select></label>
    <label>Indicator <select id="hpc-metric"></select></label>
  </div>
  <p class="viz-note" id="hpc-note">Loading the results.</p>
  <section class="viz-section" id="hpc-latest"><h3>Latest runs</h3><div class="viz-latest"></div></section>
  <section class="viz-section" id="hpc-accuracy"><h3>Accuracy over commits</h3><div class="viz-grid"></div></section>
  <section class="viz-section" id="hpc-performance"><h3>Performance over commits</h3><div class="viz-grid"></div></section>
  <section class="viz-section" id="hpc-scaling"><h3>Thread scaling</h3><div class="viz-grid"></div></section>
</div>
<script type="module" src="../assets/hpc.js"></script>
```
