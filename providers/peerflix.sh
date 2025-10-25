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
    if ! response=$(curl -sS -f --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        "$search_url" 2>/dev/null); then
        log "Failed to query The Pirate Bay"
        echo '[]'
        return 0
    fi

    local tmp_file
    tmp_file=$(mktemp)

    local single_quote=$'\''
    while IFS= read -r match; do
        local id title
        id=$(echo "$match" | sed -n 's/.*description\.php?id=\([^\"]*\)".*/\1/p')
        title=$(echo "$match" | sed -n 's/.*>\([^<]*\)<\/a>.*/\1/p')
        if [[ -n "$id" ]] && [[ -n "$title" ]]; then
            title=${title//&amp;/&}
            title=${title//&quot;/"}
            title=${title//&#39;/$single_quote}
            title=${title//&apos;/$single_quote}
            title=${title//$'\t'/ }
            printf '%s\t%s\n' "$id" "$title" >> "$tmp_file"
        fi
    done < <(echo "$response" | grep -o 'href="/description\.php?id=[^"]*"[^>]*>[^<]*</a>' | head -10)

    local results='[]'
    if [[ -s "$tmp_file" ]]; then
        if ! results=$(jq -Rs '[split("\n")[] | select(length>0) | split("\t") | {id: .[0], title: .[1], provider: "peerflix", site: "pirate_bay"}]' "$tmp_file" 2>/dev/null); then
            log "Failed to parse Pirate Bay response"
            results='[]'
        fi
    fi

    rm -f "$tmp_file"
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
    if ! response=$(curl -sS -f --max-time 30 --connect-timeout 10 \
        -H "User-Agent: $USER_AGENT" \
        "$search_url" 2>/dev/null); then
        log "Failed to query 1337x"
        echo '[]'
        return 0
    fi

    local tmp_file
    tmp_file=$(mktemp)
    local single_quote=$'\''

    while IFS= read -r match; do
        local id title
        id=$(echo "$match" | sed -n 's/.*href="\/torrent\/\([^\"]*\)".*/\1/p')
        title=$(echo "$match" | sed -n 's/.*>\([^<]*\)<\/a>.*/\1/p')
        if [[ -n "$id" ]] && [[ -n "$title" ]]; then
            title=${title//&amp;/&}
            title=${title//&quot;/"}
            title=${title//&#39;/$single_quote}
            title=${title//&apos;/$single_quote}
            title=${title//$'\t'/ }
            printf '%s\t%s\n' "$id" "$title" >> "$tmp_file"
        fi
    done < <(echo "$response" | grep -o 'href="/torrent/[^\"]*"[^>]*>[^<]*</a>' | head -10)

    local results='[]'
    if [[ -s "$tmp_file" ]]; then
        if ! results=$(jq -Rs '[split("\n")[] | select(length>0) | split("\t") | {id: .[0], title: .[1], provider: "peerflix", site: "1337x"}]' "$tmp_file" 2>/dev/null); then
            log "Failed to parse 1337x response"
            results='[]'
        fi
    fi

    rm -f "$tmp_file"
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
    if ! all_results=$(jq -n --argjson a "${pirate_bay_results:-[]}" --argjson b "${results_1337x:-[]}" '$a + $b' 2>/dev/null); then
        log "Failed to merge torrent search results"
        echo '[]'
        return 0
    fi

    local enriched_tmp
    enriched_tmp=$(mktemp)

    while IFS= read -r item; do
        local torrent_id site magnet
        torrent_id=$(echo "$item" | jq -r '.id')
        site=$(echo "$item" | jq -r '.site')
        if [[ -z "$torrent_id" ]] || [[ -z "$site" ]]; then
            continue
        fi
        if magnet=$(get_magnet_link "$torrent_id" "$site"); then
            if [[ -n "$magnet" ]]; then
                echo "$item" | jq --arg magnet "$magnet" '.id = $magnet | .magnet = $magnet | .provider = "peerflix"' >> "$enriched_tmp"
            fi
        fi
    done < <(echo "$all_results" | jq -c '.[0:10][]' 2>/dev/null)

    local enriched='[]'
    if [[ -s "$enriched_tmp" ]]; then
        if ! enriched=$(jq -s '.' "$enriched_tmp" 2>/dev/null); then
            log "Failed to construct enriched torrent list"
            enriched='[]'
        fi
    fi

    rm -f "$enriched_tmp"
    echo "$enriched"
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
            if ! response=$(curl -sS -f --max-time 30 --connect-timeout 10 \
                -H "User-Agent: $USER_AGENT" \
                "$torrent_url" 2>/dev/null); then
                log "Failed to fetch torrent details from Pirate Bay"
                return 1
            fi
            
            # Extract magnet link
            local magnet_link
            magnet_link=$(echo "$response" | grep -o 'magnet:\?xt=urn:btih:[^"[:space:]]*' | head -1)
            if [[ -z "$magnet_link" ]]; then
                log "No magnet link found on Pirate Bay for $torrent_id"
                return 1
            fi
            echo "$magnet_link"
            ;;
        "1337x")
            local torrent_url="${TORRENT_1337X}/torrent/${torrent_id}/"
            local response
            if ! response=$(curl -sS -f --max-time 30 --connect-timeout 10 \
                -H "User-Agent: $USER_AGENT" \
                "$torrent_url" 2>/dev/null); then
                log "Failed to fetch torrent details from 1337x"
                return 1
            fi
            
            # Extract magnet link
            local magnet_link
            magnet_link=$(echo "$response" | grep -o 'magnet:\?xt=urn:btih:[^"[:space:]]*' | head -1)
            if [[ -z "$magnet_link" ]]; then
                log "No magnet link found on 1337x for $torrent_id"
                return 1
            fi
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
    jq -n --arg magnet "$content_id" '[{episode: 1, title: "Full Season/Series", magnet: $magnet}]'
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

    local port="${PEERFLIX_PORT:-8888}"
    local tmp_dir
    tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t peerflix)
    local log_file="${tmp_dir}/peerflix.log"

    peerflix "$magnet_link" --port "$port" --path "$tmp_dir" >"$log_file" 2>&1 &
    local peerflix_pid=$!

    local stream_url=""
    local attempts=40
    while (( attempts > 0 )); do
        if [[ -f "$log_file" ]]; then
            stream_url=$(awk '/http:\/\// {for(i=1;i<=NF;i++){if($i ~ /^http:\/\//){print $i; exit}}}' "$log_file")
            if [[ -n "$stream_url" ]]; then
                break
            fi
        fi
        sleep 0.5
        attempts=$((attempts - 1))
    done

    if [[ -z "$stream_url" ]]; then
        log "Could not get stream URL from peerflix"
        kill "$peerflix_pid" >/dev/null 2>&1 || true
        rm -rf "$tmp_dir"
        return 1
    fi

    local session_dir="${CACHE_DIR:-${HOME}/.config/watch-cli/cache}"
    mkdir -p "$session_dir"
    printf '%s %s %s\n' "$peerflix_pid" "$tmp_dir" "$port" >"${session_dir}/peerflix.session"

    echo "$stream_url"
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
