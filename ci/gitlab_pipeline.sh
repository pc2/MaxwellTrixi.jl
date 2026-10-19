#!/usr/bin/env bash
# GitLab pipeline control for .github/workflows/hpc.yml, usable by hand with
# the same variables: GITLAB_HOST, GITLAB_PROJECT_ID, GITLAB_TOKEN (project
# access token, scope read_api, plus write_repository for push) and, for
# start, GITLAB_TRIGGER_TOKEN. The commit reaches GitLab either through the
# project's pull mirror (mirrored) or by pushing it (push, needs
# GITLAB_PROJECT_PATH).
#
#   ci/gitlab_pipeline.sh mirrored <sha> <max_minutes>   wait for the pull mirror
#   ci/gitlab_pipeline.sh push <ref> <sha>               push the commit instead
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
    local response code
    response=$(curl -sS --header "PRIVATE-TOKEN: ${GITLAB_TOKEN:?GITLAB_TOKEN is not set}" --write-out '\n%{http_code}' "$api/$1")
    code=${response##*$'\n'}
    response=${response%$'\n'*}
    if [ "${code:0:1}" != 2 ]; then
        echo "GET $api/$1 failed with HTTP $code: $response" >&2
        return 1
    fi
    printf '%s' "$response"
}

push() {
    git push --force "https://oauth2:${GITLAB_TOKEN:?GITLAB_TOKEN is not set}@$host/${GITLAB_PROJECT_PATH:?GITLAB_PROJECT_PATH is not set}.git" "$2:refs/heads/$1"
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
    echo "::notice title=GitLab pipeline $id::$(jq -r .web_url <<< "$response")"
    { pipeline_heading "$id" "$response"; jobs_links "$(jobs_json "$id")"; } | summary
}

jobs_json() {
    get "pipelines/$1/jobs?per_page=100"
}

# The table functions take the jobs JSON.
jobs_table() {
    jq -r '"| Job | Status | Duration |", "|---|---|---|",
        (.[] | "| [\(.name)](\(.web_url)) | \(.status) | \(
            if .duration then ((.duration / 60) | floor | tostring) + " min" else "" end) |")' <<< "$1"
}

jobs_links() {
    jq -r '"| Job | Link |", "|---|---|", (.[] | "| \(.name) | \(.web_url) |")' <<< "$1"
}

jobs_log() {
    jq -r '.[] | "    \(.status)\t\(.name)\t\(.web_url)"' <<< "$1"
}

# Check runs on the pipeline's commit: one per GitLab job and one for the
# pipeline with the table, updated while polling. They need gh with GH_TOKEN
# inside GitHub Actions and are skipped otherwise. GitHub points their
# Details link at the workflow run, so the GitLab links go into the text.
checks_enabled() {
    [ -n "${GH_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]
}

checks_init() {
    declare -gA check_ids check_states
    local name id
    while IFS=$'\t' read -r name id; do
        check_ids[$name]=$id
    done < <(gh api "repos/$GITHUB_REPOSITORY/commits/$1/check-runs?per_page=100" \
        --jq '.check_runs[] | select(.name | startswith("gitlab/")) | [.name, .id] | @tsv')
}

# GitLab job status to check run status and conclusion
check_state() {
    case $1 in
        success) echo "completed success" ;;
        failed) echo "completed failure" ;;
        canceled) echo "completed cancelled" ;;
        skipped | manual) echo "completed skipped" ;;
        running) echo "in_progress" ;;
        *) echo "queued" ;;
    esac
}

check_update() {
    local name=$1 sha=$2 state=$3 url=$4 title=$5 text=$6 status conclusion
    read -r status conclusion <<< "$state"
    local args=(-f "status=$status" -f "details_url=$url" -f "output[title]=$title" -f "output[summary]=$text")
    if [ -n "$conclusion" ]; then args+=(-f "conclusion=$conclusion"); fi
    if [ -n "${check_ids[$name]:-}" ]; then
        gh api --method PATCH "repos/$GITHUB_REPOSITORY/check-runs/${check_ids[$name]}" "${args[@]}" --silent
    else
        check_ids[$name]=$(gh api "repos/$GITHUB_REPOSITORY/check-runs" -f "name=$name" -f "head_sha=$sha" "${args[@]}" --jq .id)
    fi
}

checks_sync() {
    local id=$1 pipeline=$2 jobs=$3 sha status name job_status url duration state changed=false
    sha=$(jq -r .sha <<< "$pipeline")
    status=$(jq -r .status <<< "$pipeline")
    while IFS=$'\t' read -r name job_status url duration; do
        state=$(check_state "$job_status")
        if [ "${check_states[$name]:-}" = "$job_status" ]; then continue; fi
        check_update "gitlab/$name" "$sha" "$state" "$url" "$job_status" "[$name]($url): $job_status${duration:+, $duration}"
        check_states[$name]=$job_status
        changed=true
    done < <(jq -r '.[] | [.name, .status, .web_url,
        (if .duration then ((.duration / 60) | floor | tostring) + " min" else "" end)] | @tsv' <<< "$jobs")
    if [ "$changed" = true ] || [ "${check_states[pipeline]:-}" != "$status" ]; then
        check_update "gitlab/pipeline" "$sha" "$(check_state "$status")" "$(jq -r .web_url <<< "$pipeline")" \
            "pipeline $id $status" "$(pipeline_heading "$id" "$pipeline")

$(jobs_table "$jobs")"
        check_states[pipeline]=$status
    fi
}

pipeline_heading() {
    echo "### GitLab pipeline [$1]($(jq -r .web_url <<< "$2")): $(jq -r .status <<< "$2")"
}

wait_for() {
    local id=$1 max_minutes=$2 pipeline jobs status deadline
    deadline=$(( $(date +%s) + max_minutes * 60 ))
    pipeline=$(get "pipelines/$id")
    echo "::notice title=GitLab pipeline $id::$(jq -r .web_url <<< "$pipeline")"
    if checks_enabled; then checks_init "$(jq -r .sha <<< "$pipeline")"; fi
    while :; do
        pipeline=$(get "pipelines/$id")
        jobs=$(jobs_json "$id")
        status=$(jq -r .status <<< "$pipeline")
        echo "$(date -u +%H:%M) pipeline $id: $status  $(jq -r .web_url <<< "$pipeline")"
        jobs_log "$jobs"
        if checks_enabled; then checks_sync "$id" "$pipeline" "$jobs"; fi
        case $status in
            success | failed | canceled | skipped)
                output finished true
                output status "$status"
                { pipeline_heading "$id" "$pipeline"; jobs_table "$jobs"; } | summary
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
    for job in $(jobs_json "$id" | jq -r '.[] | select(.artifacts_file != null) | .id'); do
        curl -fsS --header "PRIVATE-TOKEN: $GITLAB_TOKEN" --output "job-$job.zip" "$api/jobs/$job/artifacts"
        unzip -qo "job-$job.zip" -x "*.toml" "meshes/*"
        rm "job-$job.zip"
    done
    { pipeline_heading "$id" "$pipeline"; jobs_table "$(jobs_json "$id")"; echo; julia ci/metrics_table.jl results; } | summary
    [ "$status" = success ]
}

case ${1:-} in
    mirrored) mirrored "$2" "$3" ;;
    push) push "$2" "$3" ;;
    start) start "$2" "$3" "$4" ;;
    wait) wait_for "$2" "$3" ;;
    collect) collect "$2" ;;
    *) echo "usage: $0 mirrored|push|start|wait|collect ..." >&2; exit 2 ;;
esac
