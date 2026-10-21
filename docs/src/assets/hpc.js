// Validation and performance charts from the data of github-action-benchmark,
// bench/data.js on the results branch, copied into the site by the
// documentation workflow. Each bench is named "<case>/<variant> <quantity>"
// with "threads=<n>, status=<s>, <pipeline url>" as extra; quantities with
// unit "s" are performance indicators, all others reference checks. Colors
// and ink are the roles in hpc.css. Settings on the root element:
//   data-source   URL of data.js, default ../bench/data.js
//   data-timing   regular expression marking a timing variant

const root = document.getElementById("hpc");
const settings = root.dataset;
const DATA_URL = settings.source || "../bench/data.js";
const TIMING = new RegExp(settings.timing || "^t\\d+$");
const INDICATORS = ["PID", "time per DOF per rhs"];

const state = { records: [], selectedCase: "all", metric: INDICATORS[0], slots: new Map() };

function el(tag, attributes = {}, children = []) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attributes)) {
    if (key === "class") node.className = value;
    else node.setAttribute(key, value);
  }
  for (const child of children) node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  return node;
}

function svgEl(tag, attributes = {}) {
  const node = document.createElementNS("http://www.w3.org/2000/svg", tag);
  for (const [key, value] of Object.entries(attributes)) node.setAttribute(key, value);
  return node;
}

function fmt(value) {
  if (value === undefined || value === null || Number.isNaN(value)) return "";
  const size = Math.abs(value);
  if (size === 0) return "0";
  if (size >= 1e4 || size < 1e-3) return value.toExponential(2).replace("e+", "e");
  return Number(value.toPrecision(3)).toString();
}

const fmtDate = (ms) => new Date(ms).toISOString().slice(0, 10);

function niceTicks(min, max, count) {
  if (!(max > min)) return [min];
  const step = Math.pow(10, Math.floor(Math.log10((max - min) / count)));
  const candidates = [1, 2, 5, 10].map((m) => m * step);
  const chosen = candidates.find((s) => (max - min) / s <= count) ?? candidates[3];
  const ticks = [];
  for (let v = Math.ceil(min / chosen) * chosen; v <= max + chosen / 2; v += chosen) ticks.push(Number(v.toPrecision(12)));
  return ticks;
}

function logTicks(min, max) {
  const ticks = [];
  for (let e = Math.floor(Math.log10(min)); e <= Math.ceil(Math.log10(max)); e++) {
    for (const m of [1, 2, 5]) {
      const v = m * Math.pow(10, e);
      if (v >= min / 1.05 && v <= max * 1.05) ticks.push(v);
    }
  }
  return ticks.length > 7 ? ticks.filter((v) => Math.log10(v) % 1 === 0) : ticks;
}

// A line chart: series = [{name, slot, points: [{x, y}]}], x in ms (time) or
// threads (log2), y linear or log10. Legend for two or more series, direct
// labels up to four, crosshair tooltip over all series, data table below.
function lineChart(spec) {
  const card = el("figure", { class: "viz-card", tabindex: "0" });
  const caption = el("figcaption", {}, [spec.title]);
  if (spec.subtitle) caption.append(el("small", {}, [spec.subtitle]));
  card.append(caption);
  const series = spec.series.filter((s) => s.points.length > 0);
  if (series.length === 0) {
    card.append(el("p", { class: "viz-note" }, ["no data for this selection"]));
    return card;
  }
  if (series.length >= 2) {
    card.append(el("ul", { class: "viz-legend" }, series.map((s) =>
      el("li", {}, [el("span", { class: "viz-key", style: `background: var(--series-${s.slot + 1})` }), s.name]))));
  }

  const width = Math.max(320, Math.round(root.clientWidth / (spec.columns ?? 1)) - 48);
  const height = 260;
  const margin = { top: 12, right: series.length <= 4 ? 110 : 16, bottom: 34, left: 60 };
  const xs = [...new Set(series.flatMap((s) => s.points.map((p) => p.x)))].sort((a, b) => a - b);
  const ys = series.flatMap((s) => s.points.map((p) => p.y)).filter((y) => Number.isFinite(y) && (!spec.yLog || y > 0));
  let xMin = xs[0], xMax = xs[xs.length - 1];
  if (xMin === xMax) { xMin -= spec.xType === "time" ? 86400000 : 0.5; xMax += spec.xType === "time" ? 86400000 : 0.5; }
  let yMin = Math.min(...ys), yMax = Math.max(...ys);
  if (spec.yLog) { yMin /= 1.5; yMax *= 1.5; }
  else if (spec.yFromZero || yMin < 0.5 * yMax) { yMin = 0; yMax *= 1.1; }
  else { const pad = (yMax - yMin) * 0.15 || yMax * 0.1; yMin -= pad; yMax += pad; }
  const xScale = (x) => margin.left + ((spec.xType === "log2" ? Math.log2(x) : x) - (spec.xType === "log2" ? Math.log2(xMin) : xMin))
    / ((spec.xType === "log2" ? Math.log2(xMax) : xMax) - (spec.xType === "log2" ? Math.log2(xMin) : xMin)) * (width - margin.left - margin.right);
  const yScale = (y) => margin.top + (1 - ((spec.yLog ? Math.log10(y) : y) - (spec.yLog ? Math.log10(yMin) : yMin))
    / ((spec.yLog ? Math.log10(yMax) : yMax) - (spec.yLog ? Math.log10(yMin) : yMin))) * (height - margin.top - margin.bottom);

  const svg = svgEl("svg", { viewBox: `0 0 ${width} ${height}`, width, height, role: "img", "aria-label": spec.title });
  for (const tick of spec.yLog ? logTicks(yMin, yMax) : niceTicks(yMin, yMax, 5)) {
    const y = yScale(tick);
    if (y < margin.top - 1 || y > height - margin.bottom + 1) continue;
    svg.append(svgEl("line", { class: "viz-gridline", x1: margin.left, x2: width - margin.right, y1: y, y2: y }));
    const label = svgEl("text", { x: margin.left - 8, y: y + 4, "text-anchor": "end" });
    label.textContent = fmt(tick);
    svg.append(label);
  }
  svg.append(svgEl("line", { class: "viz-axis", x1: margin.left, x2: width - margin.right, y1: height - margin.bottom, y2: height - margin.bottom }));
  const xTicks = spec.xType === "log2" ? xs : (xs.length <= 6 ? xs : [0, 0.25, 0.5, 0.75, 1].map((f) => xMin + f * (xMax - xMin)));
  for (const tick of xTicks) {
    const label = svgEl("text", { x: xScale(tick), y: height - margin.bottom + 16, "text-anchor": "middle" });
    label.textContent = spec.xType === "time" ? fmtDate(tick) : String(tick);
    svg.append(label);
  }
  if (spec.yUnit) {
    const unit = svgEl("text", { class: "viz-label", x: margin.left - 8, y: margin.top - 2, "text-anchor": "end" });
    unit.textContent = spec.yUnit;
    svg.append(unit);
  }

  const labelYs = [];
  for (const s of series) {
    const points = s.points.filter((p) => Number.isFinite(p.y) && (!spec.yLog || p.y > 0)).sort((a, b) => a.x - b.x);
    const color = `var(--series-${s.slot + 1})`;
    svg.append(svgEl("path", { class: "viz-line", stroke: color,
      d: points.map((p, i) => `${i === 0 ? "M" : "L"}${xScale(p.x).toFixed(1)},${yScale(p.y).toFixed(1)}`).join(" ") }));
    for (const p of points) svg.append(svgEl("circle", { class: "viz-marker", cx: xScale(p.x), cy: yScale(p.y), r: 4, fill: color }));
    const last = points[points.length - 1];
    if (series.length <= 4 && last && !labelYs.some((y) => Math.abs(y - yScale(last.y)) < 12)) {
      const label = svgEl("text", { class: "viz-label", x: xScale(last.x) + 8, y: yScale(last.y) + 4 });
      label.textContent = s.name;
      svg.append(label);
      labelYs.push(yScale(last.y));
    }
  }

  const crosshair = svgEl("line", { class: "viz-crosshair", y1: margin.top, y2: height - margin.bottom, visibility: "hidden" });
  svg.append(crosshair);
  const hit = svgEl("rect", { class: "viz-hit", x: margin.left, y: margin.top, width: width - margin.left - margin.right, height: height - margin.top - margin.bottom });
  svg.append(hit);
  card.append(svg);
  const tooltip = el("div", { class: "viz-tooltip", hidden: "" });
  card.append(tooltip);

  let index = -1;
  const show = (i) => {
    index = i;
    if (i < 0) { crosshair.setAttribute("visibility", "hidden"); tooltip.hidden = true; return; }
    const x = xs[i];
    crosshair.setAttribute("x1", xScale(x)); crosshair.setAttribute("x2", xScale(x)); crosshair.setAttribute("visibility", "visible");
    tooltip.replaceChildren(el("div", { class: "viz-when" }, [spec.xType === "time" ? fmtDate(x) : `${x} threads`]));
    for (const s of series) {
      const p = s.points.find((q) => q.x === x);
      if (!p) continue;
      tooltip.append(el("div", { class: "viz-row" }, [
        el("span", { class: "viz-key", style: `background: var(--series-${s.slot + 1})` }), el("strong", {}, [fmt(p.y)]), el("span", {}, [s.name])]));
    }
    tooltip.hidden = false;
    const left = xScale(x) / width * card.clientWidth;
    tooltip.style.left = `${Math.min(left + 12, card.clientWidth - tooltip.offsetWidth - 8)}px`;
    tooltip.style.top = `${caption.offsetHeight + 24}px`;
  };
  hit.addEventListener("pointermove", (event) => {
    const box = svg.getBoundingClientRect();
    const x = (event.clientX - box.left) * width / box.width;
    let best = 0;
    for (let i = 1; i < xs.length; i++) if (Math.abs(xScale(xs[i]) - x) < Math.abs(xScale(xs[best]) - x)) best = i;
    show(best);
  });
  hit.addEventListener("pointerleave", () => show(-1));
  card.addEventListener("keydown", (event) => {
    if (event.key === "ArrowRight") { show(Math.min(xs.length - 1, index + 1)); event.preventDefault(); }
    if (event.key === "ArrowLeft") { show(Math.max(0, index - 1)); event.preventDefault(); }
    if (event.key === "Escape") show(-1);
  });
  card.addEventListener("blur", () => show(-1));

  const table = el("table", {}, [el("thead", {}, [el("tr", {}, [
    el("th", {}, [spec.xType === "time" ? "date" : "threads"]), ...series.map((s) => el("th", {}, [s.name]))])])]);
  const body = el("tbody");
  for (const x of xs) {
    body.append(el("tr", {}, [el("td", {}, [spec.xType === "time" ? fmtDate(x) : String(x)]),
      ...series.map((s) => el("td", {}, [fmt(s.points.find((p) => p.x === x)?.y)]))]));
  }
  table.append(body);
  card.append(el("details", { class: "viz-table" }, [el("summary", {}, ["Data table"]), table]));
  return card;
}

function section(id) {
  const node = root.querySelector(`#${id} .viz-grid, #${id} .viz-latest`);
  node.replaceChildren();
  return node;
}

function latestRun(records) {
  const latest = Math.max(...records.map((r) => r.date));
  return records.filter((r) => r.date === latest);
}

const isCheck = (record, quantity) => record.units[quantity] !== "s";
const checks = (record) => Object.keys(record.metrics).filter((q) => isCheck(record, q));
const cases = (records) => [...new Set(records.map((r) => r.case))].sort();

function renderLatest(records) {
  const node = section("hpc-latest");
  if (records.length === 0) { node.append(el("p", { class: "viz-note" }, ["no runs recorded"])); return; }
  for (const suite of [...new Set(records.map((r) => r.suite))].sort().reverse()) {
    const latest = latestRun(records.filter((r) => r.suite === suite));
    const first = latest[0];
    node.append(el("p", { class: "viz-note" }, [
      `${suite}: ${fmtDate(first.date)}, commit `,
      el("a", { href: first.commit.url }, [first.commit.id.slice(0, 7)]), ", ",
      el("a", { href: first.pipeline_url }, ["pipeline"])]));
    const table = el("table", {}, [el("thead", {}, [el("tr", {}, ["case", "variant", "threads", "status", "checks", "PID [s]", "time/DOF/RHS [s]"].map((h) => el("th", {}, [h])))])]);
    const body = el("tbody");
    for (const r of latest.sort((a, b) => a.case.localeCompare(b.case) || a.threads - b.threads)) {
      body.append(el("tr", {}, [
        el("td", { class: "viz-text" }, [r.case]), el("td", { class: "viz-text" }, [r.variant]), el("td", {}, [String(r.threads)]),
        el("td", { class: `viz-text viz-status ${r.status}` }, [r.status]),
        el("td", { class: "viz-text" }, [checks(r).map((q) => `${q} ${fmt(r.metrics[q])}`).join(", ")]),
        el("td", {}, [fmt(r.metrics["PID"])]), el("td", {}, [fmt(r.metrics["time per DOF per rhs"])])]));
    }
    table.append(body);
    node.append(table);
  }
}

function renderAccuracy(records) {
  const node = section("hpc-accuracy");
  const checked = records.filter((r) => checks(r).length > 0);
  const names = cases(checked);
  if (names.length === 0) { node.append(el("p", { class: "viz-note" }, ["no checked runs recorded"])); return; }
  for (const name of names) {
    const rows = checked.filter((r) => r.case === name);
    const quantities = [...new Set(rows.flatMap(checks))];
    node.append(lineChart({ title: name, subtitle: "error against the reference", xType: "time", yLog: true, columns: Math.min(2, names.length),
      series: quantities.map((q, slot) => ({ name: q, slot, points: rows.filter((r) => q in r.metrics).map((r) => ({ x: r.date, y: r.metrics[q] })) })) }));
  }
}

function renderPerformance(records) {
  const node = section("hpc-performance");
  const names = cases(records);
  if (names.length === 0) { node.append(el("p", { class: "viz-note" }, ["no runs recorded"])); return; }
  for (const name of names) {
    const rows = records.filter((r) => r.case === name && Number.isFinite(r.metrics[state.metric]));
    const threads = [...new Set(rows.map((r) => r.threads))].sort((a, b) => a - b);
    const series = threads.map((t) => ({ name: `${t} threads`, slot: state.slots.get(t) % 8,
      points: rows.filter((r) => r.threads === t).map((r) => ({ x: r.date, y: r.metrics[state.metric] })) }));
    node.append(lineChart({ title: name, subtitle: `${state.metric} over commits`, xType: "time", yUnit: "s", columns: Math.min(2, names.length), series }));
  }
}

function renderScaling(records) {
  const node = section("hpc-scaling");
  const timing = records.filter((r) => TIMING.test(r.variant));
  const names = cases(timing);
  if (names.length === 0) { node.append(el("p", { class: "viz-note" }, ["no scaling runs recorded"])); return; }
  for (const name of names) {
    const latest = latestRun(timing.filter((r) => r.case === name)).sort((a, b) => a.threads - b.threads);
    node.append(lineChart({ title: name, subtitle: `latest scaling run, ${fmtDate(latest[0].date)}; flat means perfect scaling`,
      xType: "log2", yFromZero: true, yUnit: "s", columns: Math.min(2, names.length),
      series: INDICATORS.map((q, slot) => ({ name: q, slot, points: latest.filter((r) => q in r.metrics).map((r) => ({ x: r.threads, y: r.metrics[q] })) })) }));
  }
}

function render() {
  const records = state.records.filter((r) => state.selectedCase === "all" || r.case === state.selectedCase);
  renderLatest(records);
  renderAccuracy(records);
  renderPerformance(records);
  renderScaling(records);
}

function fillSelect(select, values, labels = values) {
  select.replaceChildren(...values.map((v, i) => el("option", { value: v }, [labels[i]])));
}

function setupFilters() {
  const caseSelect = root.querySelector("#hpc-case");
  const names = cases(state.records);
  fillSelect(caseSelect, ["all", ...names], ["all cases", ...names]);
  caseSelect.addEventListener("change", () => { state.selectedCase = caseSelect.value; render(); });
  const metric = root.querySelector("#hpc-metric");
  fillSelect(metric, INDICATORS);
  metric.addEventListener("change", () => { state.metric = metric.value; render(); });
}

// One record per suite entry, case and variant, with the quantities as metrics.
function toRecords(data) {
  const records = new Map();
  for (const [suite, entries] of Object.entries(data.entries)) {
    for (const entry of entries) {
      for (const bench of entry.benches) {
        const name = bench.name.match(/^([^/]+)\/(\S+) (.+)$/);
        if (!name) continue;
        const [, caseName, variant, quantity] = name;
        const key = `${suite}|${entry.commit.id}|${entry.date}|${caseName}|${variant}`;
        if (!records.has(key)) {
          const extra = bench.extra || "";
          records.set(key, { suite, date: entry.date, commit: entry.commit, case: caseName, variant,
            threads: Number(extra.match(/threads=(\d+)/)?.[1] ?? NaN),
            status: extra.match(/status=(\w+)/)?.[1] ?? "unknown",
            pipeline_url: extra.match(/https?:\/\/\S+/)?.[0] ?? "",
            metrics: {}, units: {} });
        }
        const record = records.get(key);
        record.metrics[quantity] = bench.value;
        record.units[quantity] = bench.unit;
      }
    }
  }
  return [...records.values()];
}

async function load() {
  const note = root.querySelector("#hpc-note");
  try {
    const response = await fetch(DATA_URL, { cache: "no-store" });
    if (!response.ok) throw new Error(String(response.status));
    const script = await response.text();
    state.records = toRecords(JSON.parse(script.slice(script.indexOf("=") + 1)));
  } catch (error) {
    note.textContent = "No results yet. The HPC workflow records them after each cluster run on main.";
    return;
  }
  if (state.records.length === 0) { note.textContent = "No results yet."; return; }
  note.textContent = `${state.records.length} results from ${new Set(state.records.map((r) => r.pipeline_url)).size} cluster runs on main.`;
  const threads = [...new Set(state.records.map((r) => r.threads))].sort((a, b) => a - b);
  threads.forEach((t, i) => state.slots.set(t, i));
  setupFilters();
  render();
  let pending = null;
  new ResizeObserver(() => { clearTimeout(pending); pending = setTimeout(render, 150); }).observe(root);
}

load();
