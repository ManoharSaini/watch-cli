#!/bin/bash

# Goku.to provider for watch-cli
# Implements Goku.to API scraping for movies and TV shows

set -euo pipefail

# Goku.to endpoints
GOKU_BASE="https://goku.to"
GOKU_API="${GOKU_BASE}/ajax"
GOKU_SEARCH="${GOKU_BASE}/search"

# User agent for requests
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

# Logging with injection protection
log() {
    # Sanitize input to prevent log injection
    local sanitized_msg
    sanitized_msg=$(printf '%s\n' "$1" | sed 's/[[:cntrl:]]//g' | tr -d '\n\r')
    
    # Ensure log file directory exists
    mkdir -p "${HOME}/.config/watch-cli"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Goku.to: $sanitized_msg" >> "${HOME}/.config/watch-cli/watch-cli.log"
}

# Get CSRF token
get_csrf_token() {
    local response
    response=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        -H "Referer: $GOKU_BASE/" \
        "$GOKU_BASE/")
    
    echo "$response" | grep -o 'name="csrf-token" content="[^"]*"' | sed 's/name="csrf-token" content="\([^"]*\)"/\1/'
}

# Search Goku.to
search_goku() {
    local query="$1"
    local media_type="$2"
    
    log "Searching Goku.to for $media_type: $query"
    
    # Get CSRF token
    local csrf_token
    csrf_token=$(get_csrf_token)
    
    # Build search URL
    local search_url="${GOKU_SEARCH}?keyword=${query// /%20}"
    
    # Make search request
    local response
    response=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        -H "Referer: $GOKU_BASE/" \
        -H "X-Requested-With: XMLHttpRequest" \
        "$search_url")
    
    # Parse search results
    local results
    results=$(echo "$response" | jq -r '
        .data[] | {
            id: .id,
            title: .title,
            year: (.year | tonumber? // null),
            type: .type,
            poster: .poster,
            rating: .rating,
            provider: "goku"
        }' | jq -s '.')
    
    echo "$results"
}

# Get episodes for TV shows
get_episodes() {
    local show_id="$1"
    
    log "Getting episodes for show ID: $show_id"
    
    # Get show details
    local show_url="${GOKU_BASE}/tv/${show_id}"
    local response
    response=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        -H "Referer: $GOKU_BASE/" \
        "$show_url")
    
    # Extract episodes from the page
    local episodes
    episodes=$(echo "$response" | grep -o 'data-id="[^"]*"[^>]*>Episode [0-9]*' | \
        sed 's/data-id="\([^"]*\)".*Episode \([0-9]*\)/{"episode": \2, "id": "\1", "title": "Episode \2"}/' | \
        jq -s '.')
    
    echo "$episodes"
}

# Get server list for content
get_servers() {
    local content_id="$1"
    local episode="$2"
    
    log "Getting servers for content ID: $content_id, episode: $episode"
    
    # Get CSRF token
    local csrf_token
    csrf_token=$(get_csrf_token)
    
    # Request server list
    local server_url="${GOKU_API}/v2/episode/servers"
    local response
    response=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        -H "Referer: $GOKU_BASE/" \
        -H "X-Requested-With: XMLHttpRequest" \
        -H "X-CSRF-TOKEN: $csrf_token" \
        -d "id=$content_id&episode=$episode" \
        "$server_url")
    
    # Parse server list
    local servers
    servers=$(echo "$response" | jq -r '
        .data[] | {
            name: .name,
            id: .id,
            priority: .priority
        }' | jq -s '.')
    
    echo "$servers"
}

# Get stream URL from server
get_stream_from_server() {
    local server_id="$1"
    local content_id="$2"
    local episode="$3"
    
    log "Getting stream from server ID: $server_id"
    
    # Get CSRF token
    local csrf_token
    csrf_token=$(get_csrf_token)
    
    # Request stream URL
    local stream_url="${GOKU_API}/v2/episode/sources"
    local response
    response=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        -H "Referer: $GOKU_BASE/" \
        -H "X-Requested-With: XMLHttpRequest" \
        -H "X-CSRF-TOKEN: $csrf_token" \
        -d "id=$content_id&episode=$episode&serverId=$server_id" \
        "$stream_url")
    
    # Parse stream URL
    local stream
    stream=$(echo "$response" | jq -r '.data[0].file // empty')
    
    if [[ -n "$stream" ]]; then
        echo "$stream"
    else
        log "No stream URL found from server $server_id"
        return 1
    fi
}

# Get stream URL for content
get_stream_url() {
    local content_id="$1"
    local episode="$2"
    
    log "Getting stream URL for content ID: $content_id, episode: $episode"
    
    # Get available servers
    local servers
    servers=$(get_servers "$content_id" "$episode")
    
    if [[ -z "$servers" ]]; then
        log "No servers found for content $content_id"
        return 1
    fi
    
    # Try servers in order of priority
    local server_ids
    server_ids=$(echo "$servers" | jq -r '.[] | .id' | head -5)
    
    # Use array to prevent word splitting issues
    local server_array=()
    while IFS= read -r server_id; do
        [[ -n "$server_id" ]] && server_array+=("$server_id")
    done <<< "$server_ids"
    
    for server_id in "${server_array[@]}"; do
        local stream_url
        if stream_url=$(get_stream_from_server "$server_id" "$content_id" "$episode"); then
            echo "$stream_url"
            return 0
        fi
    done
    
    log "No working stream found for content $content_id"
    return 1
}

# Main provider interface
case "${1:-}" in
    "search")
        search_goku "$2" "$3"
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
