#!/bin/bash

# Peerflix provider for watch-cli
# Implements torrent streaming via peerflix for high-quality content

set -euo pipefail

# Torrent sites
PIRATE_BAY="https://thepiratebay.org"
TORRENT_1337X="https://1337x.to"

# User agent for requests
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

# Logging with injection protection
log() {
    # Sanitize input to prevent log injection
    local sanitized_msg
    sanitized_msg=$(printf '%s\n' "$1" | sed 's/[[:cntrl:]]//g' | tr -d '\n\r')
    
    # Ensure log file directory exists
    mkdir -p "${HOME}/.config/watch-cli"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Peerflix: $sanitized_msg" >> "${HOME}/.config/watch-cli/watch-cli.log"
}

# Search The Pirate Bay
search_pirate_bay() {
    local query="$1"
    local media_type="$2"
    
    log "Searching The Pirate Bay for $media_type: $query"
    
    # Build search URL
    local search_url="${PIRATE_BAY}/search.php?q=${query// /%20}&cat=0"
    
    # Make search request
    local response
    response=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        "$search_url")
    
    # Parse results (simplified - would need more robust parsing in production)
    local results
    results=$(echo "$response" | grep -o 'href="/description\.php\?id=[^"]*"[^>]*>[^<]*</a>' | \
        head -10 | \
        sed 's/href="\/description\.php?id=\([^"]*\)"[^>]*>\([^<]*\)<\/a>/{"id": "\1", "title": "\2", "site": "pirate_bay"}/' | \
        jq -s '.')
    
    echo "$results"
}

# Search 1337x
search_1337x() {
    local query="$1"
    local media_type="$2"
    
    log "Searching 1337x for $media_type: $query"
    
    # Build search URL
    local search_url="${TORRENT_1337X}/search/${query// /%20}/1/"
    
    # Make search request
    local response
    response=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        "$search_url")
    
    # Parse results (simplified - would need more robust parsing in production)
    local results
    results=$(echo "$response" | grep -o 'href="/torrent/[^"]*"[^>]*>[^<]*</a>' | \
        head -10 | \
        sed 's/href="\/torrent\/\([^"]*\)"[^>]*>\([^<]*\)<\/a>/{"id": "\1", "title": "\2", "site": "1337x"}/' | \
        jq -s '.')
    
    echo "$results"
}

# Search torrent sites
search_torrents() {
    local query="$1"
    local media_type="$2"
    
    log "Searching torrent sites for $media_type: $query"
    
    # Search multiple sites
    local pirate_bay_results
    pirate_bay_results=$(search_pirate_bay "$query" "$media_type")
    
    local results_1337x
    results_1337x=$(search_1337x "$query" "$media_type")
    
    # Combine results
    local all_results
    all_results=$(echo "$pirate_bay_results $results_1337x" | jq -s 'add')
    
    echo "$all_results"
}

# Get magnet link from torrent site
get_magnet_link() {
    local torrent_id="$1"
    local site="$2"
    
    log "Getting magnet link for torrent ID: $torrent_id from $site"
    
    case "$site" in
        "pirate_bay")
            local torrent_url="${PIRATE_BAY}/description.php?id=${torrent_id}"
            local response
            response=$(curl -s --max-time 30 --connect-timeout 10 \
                -H "User-Agent: $USER_AGENT" \
                "$torrent_url")
            
            # Extract magnet link
            local magnet_link
            magnet_link=$(echo "$response" | grep -o 'magnet:\?xt=urn:btih:[^"]*' | head -1)
            echo "$magnet_link"
            ;;
        "1337x")
            local torrent_url="${TORRENT_1337X}/torrent/${torrent_id}/"
            local response
            response=$(curl -s --max-time 30 --connect-timeout 10 \
                -H "User-Agent: $USER_AGENT" \
                "$torrent_url")
            
            # Extract magnet link
            local magnet_link
            magnet_link=$(echo "$response" | grep -o 'magnet:\?xt=urn:btih:[^"]*' | head -1)
            echo "$magnet_link"
            ;;
    esac
}

# Get episodes for TV shows (not applicable for torrents)
get_episodes() {
    local content_id="$1"
    
    log "Getting episodes for torrent content ID: $content_id"
    
    # For torrents, we typically get the entire season/series
    # Return a single "episode" representing the full content
    echo '[{"episode": 1, "title": "Full Season/Series", "magnet": "'"$content_id"'"}]'
}

# Start peerflix streaming
start_peerflix() {
    local magnet_link="$1"
    
    log "Starting peerflix with magnet: $magnet_link"
    
    # Check if peerflix is available
    if ! command -v peerflix >/dev/null 2>&1; then
        log "peerflix not found. Please install with: npm install -g peerflix"
        return 1
    fi
    
    # Start peerflix and get the streaming URL
    local peerflix_output
    peerflix_output=$(timeout 30 peerflix "$magnet_link" --port 8888 --path /tmp/peerflix 2>&1 || true)
    
    # Extract the streaming URL from peerflix output
    local stream_url
    stream_url=$(echo "$peerflix_output" | grep -o 'http://localhost:8888/[^[:space:]]*' | head -1)
    
    if [[ -n "$stream_url" ]]; then
        echo "$stream_url"
    else
        log "Could not get stream URL from peerflix"
        return 1
    fi
}

# Get stream URL for content
get_stream_url() {
    local content_id="$1"
    local episode="$2"
    
    log "Getting stream URL for torrent content ID: $content_id, episode: $episode"
    
    # For torrents, content_id is the magnet link
    local magnet_link="$content_id"
    
    # Start peerflix streaming
    local stream_url
    if stream_url=$(start_peerflix "$magnet_link"); then
        echo "$stream_url"
    else
        log "Failed to start peerflix streaming"
        return 1
    fi
}

# Main provider interface
case "${1:-}" in
    "search")
        search_torrents "$2" "$3"
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
