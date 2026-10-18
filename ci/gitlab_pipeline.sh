#!/usr/bin/env bash
# GitLab pipeline control for .github/workflows/hpc.yml, usable by hand with
# the same variables: GITLAB_HOST, GITLAB_PROJECT_ID, GITLAB_TOKEN (project
# access token, scope read_api) and, for start, GITLAB_TRIGGER_TOKEN. The
# GitLab project pull-mirrors GitHub.
#
#   ci/gitlab_pipeline.sh mirrored <sha> <max_minutes>   wait for the mirror
#   ci/gitlab_pipeline.sh start <ref> <families> <run_url>
#   ci/gitlab_pipeline.sh wait <pipeline_id> <max_minutes>
#   ci/gitlab_pipeline.sh collect <pipeline_id>          artifacts into results/
#
# Outputs go to stdout and, inside GitHub Actions, to GITHUB_OUTPUT; tables
# go to GITHUB_STEP_SUMMARY.
set -euo pipefail

host=${GITLAB_HOST:-git.uni-paderborn.de}
api="https://$host/api/v4/projects/${GITLAB_PROJECT_ID:?GITLAB_PROJECT_ID is not set}"

output() {
    echo "$1=$2"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi
}

summary() {
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat >> "$GITHUB_STEP_SUMMARY"; else cat; fi
}

get() {
    curl -fsS --header "PRIVATE-TOKEN: ${GITLAB_TOKEN:?GITLAB_TOKEN is not set}" "$api/$1"
}

mirrored() {
    local sha=$1 max_minutes=$2 deadline
    deadline=$(( $(date +%s) + max_minutes * 60 ))
    until curl -fs --output /dev/null --header "PRIVATE-TOKEN: ${GITLAB_TOKEN:?GITLAB_TOKEN is not set}" "$api/repository/commits/$sha"; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "commit $sha did not appear on the mirror within $max_minutes minutes" >&2
            return 1
        fi
        echo "$(date -u +%H:%M) waiting for the mirror to fetch $sha"
        sleep 60
    done
    echo "commit $sha is on the mirror"
}

start() {
    local ref=$1 families=$2 run_url=$3 response id
    response=$(curl -sS --request POST "$api/trigger/pipeline" \
        --form "token=${GITLAB_TRIGGER_TOKEN:?GITLAB_TRIGGER_TOKEN is not set}" \
        --form "ref=$ref" \
        --form "variables[FAMILIES]=$families" \
        --form "variables[GITHUB_SHA]=$(git rev-parse HEAD)" \
        --form "variables[GITHUB_RUN_URL]=$run_url")
    id=$(jq -r '.id // empty' <<< "$response")
    if [ -z "$id" ]; then
        echo "starting the pipeline failed: $response" >&2
        return 1
    fi
    output pipeline_id "$id"
    output web_url "$(jq -r .web_url <<< "$response")"
    output sha "$(jq -r .sha <<< "$response")"
}

jobs_table() {
    get "pipelines/$1/jobs?per_page=100" | jq -r '
        "| Job | Status | Duration |", "|---|---|---|",
        (.[] | "| [\(.name)](\(.web_url)) | \(.status) | \(
            if .duration then ((.duration / 60) | floor | tostring) + " min" else "" end) |")'
}

pipeline_heading() {
    echo "### GitLab pipeline [$1]($(jq -r .web_url <<< "$2")): $(jq -r .status <<< "$2")"
}

wait_for() {
    local id=$1 max_minutes=$2 pipeline status deadline
    deadline=$(( $(date +%s) + max_minutes * 60 ))
    while :; do
        pipeline=$(get "pipelines/$id")
        status=$(jq -r .status <<< "$pipeline")
        echo "$(date -u +%H:%M) pipeline $id: $status"
        case $status in
            success | failed | canceled | skipped)
                output finished true
                output status "$status"
                { pipeline_heading "$id" "$pipeline"; jobs_table "$id"; } | summary
                return 0
                ;;
        esac
        if [ "$(date +%s)" -ge "$deadline" ]; then
            output finished false
            output status "$status"
            echo "still $status after $max_minutes minutes, handing over to a new run"
            return 0
        fi
        sleep 120
    done
}

collect() {
    local id=$1 pipeline status job
    pipeline=$(get "pipelines/$id")
    status=$(jq -r .status <<< "$pipeline")
    output status "$status"
    output web_url "$(jq -r .web_url <<< "$pipeline")"
    output sha "$(jq -r .sha <<< "$pipeline")"
    for job in $(get "pipelines/$id/jobs?per_page=100" | jq -r '.[] | select(.artifacts_file != null) | .id'); do
        curl -fsS --header "PRIVATE-TOKEN: $GITLAB_TOKEN" --output "job-$job.zip" "$api/jobs/$job/artifacts"
        unzip -qo "job-$job.zip" -x "*.toml" "meshes/*"
        rm "job-$job.zip"
    done
    { pipeline_heading "$id" "$pipeline"; jobs_table "$id"; echo; julia ci/metrics_table.jl results; } | summary
    [ "$status" = success ]
}

case ${1:-} in
    mirrored) mirrored "$2" "$3" ;;
    start) start "$2" "$3" "$4" ;;
    wait) wait_for "$2" "$3" ;;
    collect) collect "$2" ;;
    *) echo "usage: $0 mirrored|start|wait|collect ..." >&2; exit 2 ;;
esac
