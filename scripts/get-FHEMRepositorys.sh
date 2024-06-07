#!/bin/bash

# GitHub API-URL für die Suche nach FHEM-Repositorys
BASE_URL="https://api.github.com/search/repositories"
TAG="FHEM"

# Anzahl der Ergebnisse, die du anzeigen möchtest
PER_PAGE=2000

# API-Anfrage an GitHub
response=$(curl -s "$BASE_URL?q=topic:$TAG+language:Perl+archived:false&sort=stars&order=desc&per_page=$PER_PAGE")

# Verarbeite die Antwort
if [[ $response == *"items"* ]]; then
    while IFS= read -r repo; do
        repo_name=$(echo "$repo" | jq -r '.name')
        repo_url=$(echo "$repo" | jq -r '.html_url')
        #stars=$(echo "$repo" | jq -r '.stargazers_count')
        [[ ! $repo_name =~ (mirror|docker) ]] && echo "Repository: $repo_name - $repo_url"
    done <<< "$(echo "$response" | jq -c '.items[]')"
else
    echo "Keine Repositorys gefunden."
fi