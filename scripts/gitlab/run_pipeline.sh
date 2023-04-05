#!/bin/sh

set -eu

if [ "${TRACE:-}" ]; then set -x; fi

usage() {
    echo "Usage: $0 [--private-token PRIVATE_TOKEN] [--project PROJECT] [--branch BRANCH] [VAR1_NAME=VAR1_VALUE ...]"
    echo "Launches a GitLab pipeline on a given branch, project and variables."
    echo
    echo "Example:"
    echo "  $0 --private-token gl-... CLEAN_OPAM_CACHE=true CLEAN_DUNE_CACHE=true"
    echo
    echo "PRIVATE_TOKEN, PROJECT and BRANCH can also be set through the environment variables of the same name."
    echo "A GitLab private token must be supplied, either through --private-token or PRIVATE_TOKEN."
    echo "By default, the BRANCH is current branch of the repo in the current working directory, if any."
    echo "Likewise, the the script will attempt to infer the GitLab project from the remote/pushRemote of the current branch."
    echo
    exit 1
}


uri_encode() {
    jq -rn --arg x "$1" '$x|@uri'
}

git_branch() {
    if [ -d .git ] || [ -f .git ]; then
        git rev-parse --abbrev-ref HEAD
    fi
}

gitlab_project_of() {
    if [ -d .git ] || [ -f .git ]; then
        br=$(git_branch)
        remote=$(git config --get branch."$br".pushRemote)
        if [ -z "$remote" ]; then
            remote=$(git config --get branch."$br".remote)
        fi
        git remote get-url "$remote" | sed 's/.*gitlab\.com:\(.*\)\.git/\1/'
    fi
}

project=$(gitlab_project_of || echo "")
if [ -n "${PROJECT_ID:-}" ]; then
    project=$PROJECT_ID
fi

branch=$(git_branch || echo "")
if [ -n "${BRANCH:-}" ]; then
    project=$BRANCH
fi

private_token=${PRIVATE_TOKEN:-}

while [ $# -gt 0 ]; do
    case "$1" in
        "-t" | "--private-token")
            private_token="$2"
            shift
            ;;
        "-p" | "--project")
            project="$2"
            shift
            ;;
        "-b" | "--branch")
            branch="$2"
            shift
            ;;
        "-h" | "--help")
            usage
            ;;

        *=*)
            break;
    esac
    shift
done

if [ -z "$private_token" ]; then
    echo "GitLab token has not been supplied through --private-token or PRIVATE_TOKEN. See $0 --help."
    exit 1
fi

if [ -z "$project" ]; then
    echo "GitLab project has not been supplied through --project or PROJECT, and could not be inferred. See $0 --help."
    exit 1
fi

if [ -z "$branch" ]; then
    echo "Target branch has not been supplied through --branch or BRANCH, and could not be inferred. See $0 --help."
    exit 1
fi

data=$(jq -n --arg branch "$branch" '{"ref": $branch, "variables": []}')
if [ $# -gt 0 ]; then
    while [ $# -gt 0 ]; do
        # "$1" does not contain '='
        if [ "${1#*=}" = "$1" ] ; then
            usage
        fi
        key=$(echo "$1" | cut -d'=' -f1)
        value=$(echo "$1" | cut -d'=' -f2-)
        data=$(echo "$data" \
                   | jq --arg key "$key" \
                        --arg value "$value" \
                        '.variables=.variables+[{"key": $key, "value": $value}]'
            )
        shift
    done
fi

echo "Creating pipeline on branch '$branch' on project '$project'..."

response=$(curl --silent --request POST \
     --header 'Content-Type: application/json' \
     --header "Private-Token: $private_token" \
     --data "$data" \
     "https://gitlab.com/api/v4/projects/$(uri_encode "$project")/pipeline")
web_url=$(echo "$response" | jq -r ".web_url")
pipeline_id=$(echo "$response" | jq -r ".id")
if [ "$web_url" != "null" ]; then
    echo "Pipeline #$pipeline_id created at $web_url"
    echo "Variables: "
    curl -s  \
     --header "Private-Token: $private_token" \
     "https://gitlab.com/api/v4/projects/$(uri_encode "$project")/pipelines/$pipeline_id/variables" | jq
else
    echo "ERROR: Could not find the 'web_url' in response:"
    echo "$response" | jq
    exit 1
fi
