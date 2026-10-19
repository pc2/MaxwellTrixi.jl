#!/usr/bin/env bash
# Results of the case jobs, results/<case>/<variant>/{metrics.txt,junit.xml}.
# Metrics are OpenMetrics lines "<prefix>_<name>{k="v",...} <value>".
#
#   ci/results.sh table <results>                          markdown table
#   ci/results.sh records <results> <ref> <pipeline.json>  one JSON record per case
#   ci/results.sh publish <results> <ref> <pipeline.json>  append records and metrics to the results branch
#
# Needs jq. publish runs inside the GitHub checkout with push access.
set -euo pipefail

RESULTS_BRANCH=${RESULTS_BRANCH:-hpc-results}

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
        parse_metrics "$file" | jq -r '
            [.labels.case, .labels.variant, .labels.threads,
             (.metrics | to_entries
                | map(select(.key | test("_(relative_error|absolute_error|fraction|plus_reflectance)$")))
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

records() {
    local results=$1 ref=$2 pipeline=$3 file run_url=""
    if [ -n "${GITHUB_RUN_ID:-}" ]; then
        run_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/$GITHUB_RUN_ID"
    fi
    for file in $(metrics_files "$results"); do
        parse_metrics "$file" | jq -c --slurpfile pipeline "$pipeline" --arg ref "$ref" \
            --arg status "$(junit_status "$(dirname "$file")/junit.xml")" --arg run_url "$run_url" '
            { date: $pipeline[0].created_at, ref: $ref, commit: $pipeline[0].sha,
              pipeline: $pipeline[0].id, pipeline_url: $pipeline[0].web_url, run_url: $run_url,
              case: .labels.case, variant: .labels.variant,
              threads: (.labels.threads | tonumber), ranks: (.labels.ranks | tonumber),
              trixi: .labels.trixi, julia: .labels.julia, status: $status, metrics: .metrics }'
    done
}

publish() {
    local results=$1 ref=$2 pipeline=$3 id sha7 stamp dir run_dir file target
    id=$(jq -r .id "$pipeline")
    sha7=$(jq -r '.sha[:7]' "$pipeline")
    stamp=$(jq -r '.created_at[:19]' "$pipeline" | tr -d ':' | tr T _)
    dir=$(mktemp -d)
    if git ls-remote --exit-code --heads origin "$RESULTS_BRANCH" > /dev/null; then
        git fetch -q origin "$RESULTS_BRANCH"
        git worktree add -q "$dir" FETCH_HEAD
        git -C "$dir" checkout -q -B "$RESULTS_BRANCH"
    else
        git worktree add -q --orphan -b "$RESULTS_BRANCH" "$dir"
    fi
    run_dir="$dir/runs/${stamp}_${sha7}_${id}"
    for file in $(metrics_files "$results"); do
        target="$run_dir/${file#"$results"/}"
        mkdir -p "$(dirname "$target")"
        cp "$file" "$target"
    done
    records "$results" "$ref" "$pipeline" >> "$dir/history.jsonl"
    git -C "$dir" add -A
    git -C "$dir" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
        commit -q -m "results of pipeline $id for $sha7 on $ref"
    git -C "$dir" push -q origin "$RESULTS_BRANCH" || {
        git -C "$dir" pull -q --rebase origin "$RESULTS_BRANCH"
        git -C "$dir" push -q origin "$RESULTS_BRANCH"
    }
    echo "appended $(records "$results" "$ref" "$pipeline" | wc -l | tr -d ' ') records to $RESULTS_BRANCH as $(git -C "$dir" rev-parse --short HEAD)"
    git worktree remove --force "$dir"
}

case ${1:-} in
    table) table "$2" ;;
    records) records "$2" "$3" "$4" ;;
    publish) publish "$2" "$3" "$4" ;;
    *) echo "usage: $0 table|records|publish ..." >&2; exit 2 ;;
esac
