#!/bin/bash

# AllAnime provider for watch-cli
# Implements AllAnime GraphQL API for anime search, episodes, and streaming

set -euo pipefail

# AllAnime API endpoints
ALLANIME_API="https://api.allanime.co/api"
ALLANIME_GRAPHQL="${ALLANIME_API}/graphql"
ALLANIME_CDN="https://cdn.allanime.co"

# User agent for requests
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

# Logging with injection protection
log() {
    # Sanitize input to prevent log injection
    local sanitized_msg
    sanitized_msg=$(printf '%s\n' "$1" | sed 's/[[:cntrl:]]//g' | tr -d '\n\r')
    
    # Ensure log file directory exists
    mkdir -p "${HOME}/.config/watch-cli"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - AllAnime: $sanitized_msg" >> "${HOME}/.config/watch-cli/watch-cli.log"
}

# Make GraphQL request to AllAnime
make_graphql_request() {
    local query="$1"
    local variables="$2"
    
    # Validate inputs
    if [[ -z "$query" ]]; then
        log "Empty GraphQL query"
        return 1
    fi
    
    if [[ -z "$variables" ]]; then
        log "Empty GraphQL variables"
        return 1
    fi
    
    # Validate JSON format of variables
    if ! echo "$variables" | jq . >/dev/null 2>&1; then
        log "Invalid JSON in variables: $variables"
        return 1
    fi
    
    # Create JSON payload safely
    local json_payload
    json_payload=$(jq -n --arg query "$query" --argjson variables "$variables" '{query: $query, variables: $variables}')
    
    if [[ -z "$json_payload" ]]; then
        log "Failed to create JSON payload"
        return 1
    fi
    
    local response
    if ! response=$(curl -s --max-time 30 --connect-timeout 10 \
        -H "Content-Type: application/json" \
        -H "User-Agent: $USER_AGENT" \
        -H "Referer: https://allanime.co/" \
        -d "$json_payload" \
        "$ALLANIME_GRAPHQL" 2>/dev/null); then
        log "Failed to make GraphQL request"
        return 1
    fi
    
    # Validate response
    if [[ -z "$response" ]]; then
        log "Empty response from GraphQL API"
        return 1
    fi
    
    # Check for errors in response
    if echo "$response" | jq -e '.errors' >/dev/null 2>&1; then
        log "GraphQL errors in response: $(echo "$response" | jq -r '.errors')"
        return 1
    fi
    
    echo "$response"
}

# Search for anime
search_anime() {
    local query="$1"
    
    # Validate input
    if [[ -z "$query" ]]; then
        log "Empty search query"
        return 1
    fi
    
    # Sanitize query to prevent injection
    if [[ "$query" =~ [\"\'\\] ]]; then
        log "Query contains potentially dangerous characters: $query"
        return 1
    fi
    
    log "Searching for anime: $query"
    
    # GraphQL query for anime search
    local search_query='
    query($search: SearchInput) {
        shows(search: $search) {
            edges {
                _id
                name
                englishName
                nativeName
                thumbnail
                availableEpisodes {
                    sub
                    dub
                }
                year
                season
                status
                type
            }
        }
    }'
    
    local variables="{\"search\":{\"allowAdult\":true,\"allowUnknown\":true,\"query\":\"$query\"}}"
    
    local response
    if ! response=$(make_graphql_request "$search_query" "$variables"); then
        log "Failed to search anime"
        return 1
    fi
    
    # Parse response and format for watch-cli with error handling
    local results
    if ! results=$(echo "$response" | jq -r '
        .data.shows.edges[] | {
            id: ._id,
            title: (.englishName // .name),
            year: .year,
            thumbnail: .thumbnail,
            episodes: .availableEpisodes,
            status: .status,
            type: .type,
            provider: "allanime"
        }' | jq -s '.' 2>/dev/null); then
        log "Failed to parse search results"
        return 1
    fi
    
    # Validate results
    if [[ -z "$results" ]] || [[ "$results" == "null" ]] || [[ "$results" == "[]" ]]; then
        log "No search results found"
        return 1
    fi
    
    echo "$results"
}

# Get episodes for an anime
get_episodes() {
    local anime_id="$1"
    
    log "Getting episodes for anime ID: $anime_id"
    
    # GraphQL query for episodes
    local episodes_query='
    query($showId: String!) {
        show(_id: $showId) {
            _id
            name
            availableEpisodes {
                sub {
                    episodeString
                    notes
                }
                dub {
                    episodeString
                    notes
                }
            }
        }
    }'
    
    local variables="{\"showId\":\"$anime_id\"}"
    
    local response
    response=$(make_graphql_request "$episodes_query" "$variables")
    
    # Parse episodes
    local episodes
    episodes=$(echo "$response" | jq -r '
        .data.show.availableEpisodes.sub[]? | {
            episode: (.episodeString | tonumber),
            title: .notes,
            type: "sub"
        }' | jq -s '.')
    
    # Add dub episodes if available
    local dub_episodes
    dub_episodes=$(echo "$response" | jq -r '
        .data.show.availableEpisodes.dub[]? | {
            episode: (.episodeString | tonumber),
            title: .notes,
            type: "dub"
        }' | jq -s '.')
    
    # Combine sub and dub episodes
    local all_episodes
    all_episodes=$(echo "$episodes $dub_episodes" | jq -s 'add | sort_by(.episode)')
    
    echo "$all_episodes"
}

# Get stream URL for an episode
get_stream_url() {
    local anime_id="$1"
    local episode="$2"
    
    log "Getting stream URL for anime ID: $anime_id, episode: $episode"
    
    # GraphQL query for episode sources
    local sources_query='
    query($showId: String!, $episodeString: String!) {
        episode(showId: $showId, episodeString: $episodeString) {
            episodeString
            sourceUrls {
                sourceUrl
                notes
                priority
            }
        }
    }'
    
    local variables="{\"showId\":\"$anime_id\",\"episodeString\":\"$episode\"}"
    
    local response
    response=$(make_graphql_request "$sources_query" "$variables")
    
    # Parse stream URLs and select the best one
    local stream_url
    stream_url=$(echo "$response" | jq -r '
        .data.episode.sourceUrls[] | 
        select(.sourceUrl != null) |
        .sourceUrl' | head -1)
    
    if [[ -z "$stream_url" ]]; then
        log "No stream URL found for episode $episode"
        return 1
    fi
    
    # If it's a CDN URL, we might need to resolve it further
    if [[ "$stream_url" == *"cdn.allanime.co"* ]]; then
        # Try to get the actual video URL from the CDN
        local cdn_response
        cdn_response=$(curl -s --max-time 30 --connect-timeout 10 \
            -H "User-Agent: $USER_AGENT" \
            -H "Referer: https://allanime.co/" \
            "$stream_url")
        
        # Look for video URLs in the response
        local video_url
        video_url=$(echo "$cdn_response" | grep -o 'https\?://[^"[:space:]]\+\.\(mp4\|m3u8\|mkv\)' | head -1)
        
        if [[ -n "$video_url" ]]; then
            stream_url="$video_url"
        fi
    fi
    
    echo "$stream_url"
}

# Main provider interface
case "${1:-}" in
    "search")
        search_anime "$2"
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
