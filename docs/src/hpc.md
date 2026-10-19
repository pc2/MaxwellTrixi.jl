# Validation and performance

Results of the full-resolution runs on the cluster, one record per case and
run, as the HPC workflow appends them to the branch `hpc-results`. Each record
carries the branch and commit, the pipeline, the reference checks of the case
and Trixi's performance indicators, see [Building and publishing](@ref) for
how the runs are started and collected.

The accuracy charts follow the `default` variant of each case, the only one
with reference checks. The performance charts show the chosen indicator per
thread count over commits, and the scaling chart the latest run of the timing
variants; since both indicators are scaled by the thread count, a flat line
means perfect scaling. Hover or use the arrow keys on a chart for the values
at one commit, and open its data table for all of them.

```@raw html
<link rel="stylesheet" href="../assets/hpc.css">
<div class="viz-root" id="hpc">
  <div class="viz-filters">
    <label>Branch <select id="hpc-branch"></select></label>
    <label>Case <select id="hpc-case"></select></label>
    <label>Indicator <select id="hpc-metric"></select></label>
  </div>
  <p class="viz-note" id="hpc-note">Loading the history.</p>
  <section class="viz-section" id="hpc-latest"><h3>Latest run</h3><div class="viz-latest"></div></section>
  <section class="viz-section" id="hpc-accuracy"><h3>Accuracy over commits</h3><div class="viz-grid"></div></section>
  <section class="viz-section" id="hpc-performance"><h3>Performance over commits</h3><div class="viz-grid"></div></section>
  <section class="viz-section" id="hpc-scaling"><h3>Thread scaling</h3><div class="viz-grid"></div></section>
</div>
<script type="module" src="../assets/hpc.js"></script>
```
