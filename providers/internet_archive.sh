#!/bin/bash

# Internet Archive provider for watch-cli
# Scrapes Internet Archive for movies and TV shows

set -euo pipefail

# Internet Archive API
IA_API="https://archive.org/advancedsearch.php"
IA_BASE="https://archive.org"

# User agent for requests
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

# Logging with injection protection
log() {
    # Sanitize input to prevent log injection
    local sanitized_msg
    sanitized_msg=$(printf '%s\n' "$1" | sed 's/[[:cntrl:]]//g' | tr -d '\n\r')
    
    # Ensure log file directory exists
    mkdir -p "${HOME}/.config/watch-cli"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Internet Archive: $sanitized_msg" >> "${HOME}/.config/watch-cli/watch-cli.log"
}

# Search Internet Archive
search_archive() {
    local query="$1"
    local media_type="$2"
    
    log "Searching Internet Archive for $media_type: $query"
    
    # Build search parameters
    local search_params=""
    case "$media_type" in
        "movie")
            search_params="mediatype:movies"
            ;;
        "tv")
            search_params="mediatype:tv"
            ;;
        *)
            search_params="mediatype:(movies OR tv)"
            ;;
    esac
    
    # Make API request
    local response
    response=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        "${IA_API}?q=${query// /%20}%20AND%20${search_params// /%20}&output=json&rows=50")
    
    # Parse response
    local results
    results=$(echo "$response" | jq -r '
        .response.docs[] | {
            id: .identifier,
            title: .title,
            year: (.date | tonumber? // null),
            description: .description,
            creator: .creator,
            language: .language,
            runtime: .runtime,
            provider: "internet_archive"
        }' | jq -s '.')
    
    echo "$results"
}

# Get episodes/seasons for TV shows
get_episodes() {
    local show_id="$1"
    
    log "Getting episodes for show ID: $show_id"
    
    # Get show metadata
    local metadata_url="${IA_BASE}/metadata/${show_id}"
    local metadata
    metadata=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        "$metadata_url")
    
    # Extract files that look like episodes
    local episodes
    episodes=$(echo "$metadata" | jq -r '
        .files[] | 
        select(.name | test("\\.(mp4|avi|mkv|mov|wmv)$"; "i")) |
        select(.name | test("episode|ep|s[0-9]+e[0-9]+|part"; "i")) |
        {
            episode: (.name | capture("episode\\s*(?<ep>[0-9]+)"; "i") | .ep // .name | capture("ep\\s*(?<ep>[0-9]+)"; "i") | .ep // "1" | tonumber),
            title: .name,
            url: ("https://archive.org/download/" + .name),
            size: .size,
            format: .format
        }' | jq -s '. | sort_by(.episode)')
    
    echo "$episodes"
}

# Get direct stream URL
get_stream_url() {
    local item_id="$1"
    local episode="$2"
    
    log "Getting stream URL for item ID: $item_id, episode: $episode"
    
    # For movies, get the main video file
    if [[ -z "${episode:-}" ]] || [[ "$episode" == "1" ]]; then
        # Get the main video file for the item
        local metadata_url="${IA_BASE}/metadata/${item_id}"
        local metadata
        metadata=$(curl -s --max-time 30 --connect-timeout 10 \
            -H "User-Agent: $USER_AGENT" \
            "$metadata_url")
        
        # Find the best quality video file
        local video_url
        video_url=$(echo "$metadata" | jq -r '
            .files[] | 
            select(.name | test("\\.(mp4|avi|mkv|mov|wmv)$"; "i")) |
            select(.name | test("^[^/]*$")) |  # Main file, not in subdirectory
            .name' | head -1)
        
        if [[ -n "$video_url" ]]; then
            echo "${IA_BASE}/download/${item_id}/${video_url}"
            return 0
        fi
    fi
    
    # For TV shows, get the specific episode
    local episodes
    episodes=$(get_episodes "$item_id")
    
    local episode_url
    episode_url=$(echo "$episodes" | jq -r ".[] | select(.episode == $episode) | .url")
    
    if [[ -n "$episode_url" ]]; then
        echo "$episode_url"
    else
        log "No stream URL found for episode $episode"
        return 1
    fi
}

# Main provider interface
case "${1:-}" in
    "search")
        search_archive "$2" "$3"
        ;;
    "episodes")
        get_episodes "$2"
        ;;
    "stream")
        get_stream_url "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {search|episodes|stream} [args...]"
        exit 1
        ;;
esac
