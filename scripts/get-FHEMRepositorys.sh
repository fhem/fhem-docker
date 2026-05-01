#!/bin/bash

# GitHub API-URL für die Suche nach FHEM-Repositorys
BASE_URL="https://api.github.com/search/repositories"
TOPIC="topic:FHEM"
README='"update+all+https%3A%2F%2Fraw.githubusercontent.com"+OR++in%3Areadme+"update+add+https%3A%2F%2Fraw.githubusercontent.com"'
EXCLUDED_REPOSITORIES_FILE="$(dirname "$0")/excluded_repositories.txt"

# Anzahl der Ergebnisse, die du anzeigen möchtest
PER_PAGE=2000

# API-Anfrage an GitHub
response=$(curl -s "$BASE_URL?q=${TOPIC}+archived:false+${README}&sort=stars&order=desc&per_page=$PER_PAGE")

is_excluded_repository() {
    local repository="$1"
    local excluded_repository

    [[ -f "$EXCLUDED_REPOSITORIES_FILE" ]] || return 1

    while IFS= read -r excluded_repository; do
        excluded_repository="${excluded_repository%%#*}"
        excluded_repository="${excluded_repository#"${excluded_repository%%[![:space:]]*}"}"
        excluded_repository="${excluded_repository%"${excluded_repository##*[![:space:]]}"}"
        [[ -z "$excluded_repository" ]] && continue
        [[ "${repository,,}" == "${excluded_repository,,}" ]] && return 0
    done < "$EXCLUDED_REPOSITORIES_FILE"

    return 1
}

# Verarbeite die Antwort
if [[ $response == *"items"* ]]; then
    while IFS= read -r repo; do
        repo_name=$(echo "$repo" | jq -r '.name')
        repo_full_name=$(echo "$repo" | jq -r '.full_name')
        repo_url=$(echo "$repo" | jq -r '.html_url')
        #stars=$(echo "$repo" | jq -r '.stargazers_count')
        if is_excluded_repository "$repo_full_name"; then
            echo "Excluded repository: $repo_full_name - $repo_url" >&2
            continue
        fi
        [[ ! $repo_name =~ (mirror|docker) ]] && echo "Repository: $repo_name - $repo_url"
    done <<< "$(echo "$response" | jq -c '.items[]')"
else
    echo "Keine Repositorys gefunden."
fi
