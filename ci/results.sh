#!/usr/bin/env bash
# Results of the case jobs, results/<case>/<variant>/{metrics.txt,junit.xml}.
# Metrics are OpenMetrics lines "<prefix>_<name>{k="v",...} <value>".
#
#   ci/results.sh table <results>                                  markdown table
#   ci/results.sh benchmark <results> <family> <pipeline.json>     benchmark-action JSON, customSmallerIsBetter
#
# Families: scaling holds the timing variants t<n>, validation the rest.
# Needs jq.
set -euo pipefail

CHECK_PATTERN='_(relative_error|absolute_error|fraction|plus_reflectance)$'

# metrics.txt to JSON: {labels: {...}, metrics: {...}}
parse_metrics() {
    sed -nE 's/^[A-Za-z0-9]+_([A-Za-z0-9_]+)\{([^}]*)\} (.*)$/\1\t\2\t\3/p' "$1" | jq -R -s '
        split("\n") | map(select(length > 0) | split("\t"))
        | { labels: (.[0][1] | [scan("([a-z_]+)=\"([^\"]*)\"")] | map({(.[0]): .[1]}) | add),
            metrics: (map({(.[0]): (.[2] | tonumber)}) | add) }'
}

# pass, fail or unknown from the JUnit file next to the metrics
junit_status() {
    local junit=$1 failures
    [ -f "$junit" ] || { echo unknown; return; }
    failures=$(grep -oE '(failures|errors)="[0-9]+"' "$junit" | grep -oE '[0-9]+' | awk '{ sum += $1 } END { print sum + 0 }')
    if [ "$failures" -eq 0 ]; then echo pass; else echo fail; fi
}

metrics_files() {
    find "$1" -mindepth 3 -maxdepth 3 -name metrics.txt | sort
}

table() {
    local results=$1 file
    echo "| Case | Variant | Threads | Checks | PID [s] | time/DOF/RHS [s] | Steps |"
    echo "|---|---|---|---|---|---|---|"
    for file in $(metrics_files "$results"); do
        parse_metrics "$file" | jq -r --arg check "$CHECK_PATTERN" '
            [.labels.case, .labels.variant, .labels.threads,
             (.metrics | to_entries
                | map(select(.key | test($check)))
                | map((.key | sub("_(relative|absolute)_error$"; "") | gsub("_"; " ")) + "=" + (.value | tostring))
                | join(";")),
             (.metrics.pid_seconds // ""), (.metrics.time_per_dof_per_rhs_seconds // ""), (.metrics.steps // "")]
            | @tsv'
    done | awk -F'\t' '
        function fmt(x) { if (x == "") return ""; if (x == int(x)) return sprintf("%d", x); return sprintf("%.3g", x) }
        {
            n = split($4, parts, ";"); checks = ""
            for (i = 1; i <= n; i++) {
                split(parts[i], kv, "=")
                if (kv[1] != "") checks = checks (checks == "" ? "" : ", ") kv[1] " " fmt(kv[2])
            }
            print "| " $1 " | " $2 " | " $3 " | " checks " | " fmt($5) " | " fmt($6) " | " fmt($7) " |"
        }'
}

# One entry per indicator and reference check, named "<case>/<variant> <quantity>",
# with threads, status and the pipeline in the tooltip text.
benchmark() {
    local results=$1 family=$2 pipeline=$3 file
    for file in $(metrics_files "$results"); do
        parse_metrics "$file" | jq -c --arg family "$family" --arg check "$CHECK_PATTERN" \
            --arg status "$(junit_status "$(dirname "$file")/junit.xml")" --arg url "$(jq -r .web_url "$pipeline")" '
            (if (.labels.variant | test("^t[0-9]+$")) then "scaling" else "validation" end) as $kind
            | select($kind == $family)
            | (.labels.case + "/" + .labels.variant) as $prefix
            | ("threads=" + .labels.threads + ", status=" + $status + ", " + $url) as $extra
            | [ (if .metrics.pid_seconds then {name: ($prefix + " PID"), unit: "s", value: .metrics.pid_seconds, extra: $extra} else empty end),
                (if .metrics.time_per_dof_per_rhs_seconds then {name: ($prefix + " time per DOF per rhs"), unit: "s", value: .metrics.time_per_dof_per_rhs_seconds, extra: $extra} else empty end),
                (.metrics | to_entries[] | select(.key | test($check))
                 | {name: ($prefix + " " + (.key | sub("_(relative|absolute)_error$"; "") | gsub("_"; " "))),
                    unit: (if (.key | test("relative")) then "relative error" elif (.key | test("absolute")) then "absolute error" else "ratio" end),
                    value: .value, extra: $extra}) ]
            | .[]'
    done | jq -s .
}

case ${1:-} in
    table) table "$2" ;;
    benchmark) benchmark "$2" "$3" "$4" ;;
    *) echo "usage: $0 table|benchmark ..." >&2; exit 2 ;;
esac
