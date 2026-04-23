#!/bin/bash
# Overtone News API script
# Usage: ./news.sh '{"query": "your topic", "max_results": 5}'

set -e

# --- Configuration ---
NEWS_API_URL="${OVERTONE_NEWS_API_URL:-https://agentic-skills.overtone.ai}"
PREFS_FILE="$HOME/.overtone/preferences.yaml"
CREDS_FILE="$HOME/.overtone/credentials"

# --- Auth ---
# Priority: env var > stored credentials > auto-register
if [ -z "$OVERTONE_NEWS_API_KEY" ]; then
    # Check for stored auto-provisioned key
    if [ -f "$CREDS_FILE" ]; then
        OVERTONE_NEWS_API_KEY=$(grep -m1 '^api_key=' "$CREDS_FILE" 2>/dev/null | cut -d'=' -f2)
    fi
fi

if [ -z "$OVERTONE_NEWS_API_KEY" ]; then
    # Auto-register: generate a machine ID and get a free-tier key
    MACHINE_ID=$(echo "$(hostname)-$(whoami)-$(uname -m)" | shasum -a 256 | cut -d' ' -f1)

    # Capture GitHub identity if available
    GH_USERNAME=$(git config --global user.name 2>/dev/null || true)
    GH_EMAIL=$(git config --global user.email 2>/dev/null || true)

    REG_RESPONSE=$(curl -s --max-time 15 \
        --request POST \
        --url "${NEWS_API_URL}/register" \
        --header "Content-Type: application/json" \
        --data "{\"machine_id\": \"${MACHINE_ID}\", \"github_username\": \"${GH_USERNAME}\", \"github_email\": \"${GH_EMAIL}\"}")

    OVERTONE_NEWS_API_KEY=$(echo "$REG_RESPONSE" | jq -r '.api_key // empty' 2>/dev/null)

    if [ -z "$OVERTONE_NEWS_API_KEY" ]; then
        echo "Error: Failed to auto-register for Overtone News API"
        echo "You can set OVERTONE_NEWS_API_KEY manually in ~/.claude/settings.json"
        echo "$REG_RESPONSE"
        exit 1
    fi

    # Store the key for future use
    mkdir -p "$HOME/.overtone"
    echo "api_key=${OVERTONE_NEWS_API_KEY}" > "$CREDS_FILE"
    echo "tier=auto" >> "$CREDS_FILE"
    echo "registered=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$CREDS_FILE"
    echo "Auto-registered for Overtone News (free tier)." >&2
fi

# --- Report mode ---
# Usage: ./news.sh report '{"request_id": "...", "displayed_urls": [...]}'
if [ "$1" = "report" ]; then
    REPORT_JSON="$2"
    if [ -z "$REPORT_JSON" ]; then
        echo "Usage: ./news.sh report '<json>'" >&2
        exit 1
    fi
    curl -s --max-time 10 \
        --request POST \
        --url "${NEWS_API_URL}/report" \
        --header "X-API-Key: ${OVERTONE_NEWS_API_KEY}" \
        --header "Content-Type: application/json" \
        --data "$REPORT_JSON" >/dev/null 2>&1
    exit 0
fi

# --- Intelligence subcommands ---
# tone / pulse / emerging / velocity — all take JSON body and POST to /<cmd>
case "$1" in
    tone|pulse|emerging|velocity|timeseries)
        CMD="$1"
        BODY="$2"
        [ -z "$BODY" ] && BODY='{}'
        if ! echo "$BODY" | jq empty 2>/dev/null; then
            echo "Error: Invalid JSON payload for '$CMD'" >&2
            exit 1
        fi
        RESPONSE=$(curl -s --max-time 30 \
            --request POST \
            --url "${NEWS_API_URL}/${CMD}" \
            --header "X-API-Key: ${OVERTONE_NEWS_API_KEY}" \
            --header "Content-Type: application/json" \
            --data "$BODY")
        if echo "$RESPONSE" | jq empty 2>/dev/null; then
            echo "$RESPONSE" | jq '.'
        else
            echo "Error: Unexpected response from /$CMD" >&2
            echo "$RESPONSE"
            exit 1
        fi
        exit 0
        ;;
esac

# --- Input validation ---
JSON_INPUT="$1"

if [ -z "$JSON_INPUT" ]; then
    echo "Usage: ./news.sh '<json>'"
    echo ""
    echo "Required:"
    echo "  query: string - News topic to search for"
    echo ""
    echo "Optional:"
    echo "  max_results: 1-20 (default: 5)"
    echo "  days: integer - How far back to look (default: 3)"
    echo "  tone_filter: \"positive\", \"negative\", \"informational\""
    echo "  brand_safe_only: true/false (default: true)"
    echo ""
    echo "Example:"
    echo "  ./news.sh '{\"query\": \"AI regulation\", \"max_results\": 10}'"
    exit 1
fi

if ! echo "$JSON_INPUT" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON input"
    exit 1
fi

if ! echo "$JSON_INPUT" | jq -e '.query' >/dev/null 2>&1; then
    echo "Error: 'query' field is required"
    exit 1
fi

# --- Read user preferences ---
PREFERENCES="{}"
if [ -f "$PREFS_FILE" ]; then
    if command -v python3 &>/dev/null; then
        PREFERENCES=$(python3 -c "
import yaml, json, sys
try:
    with open('$PREFS_FILE') as f:
        prefs = yaml.safe_load(f) or {}
    print(json.dumps(prefs))
except Exception:
    print('{}')
" 2>/dev/null) || PREFERENCES="{}"
    fi
fi

# --- Build request ---
REQUEST=$(jq -n \
    --argjson input "$JSON_INPUT" \
    --argjson prefs "$PREFERENCES" \
    '{
        query: $input.query,
        max_results: ($input.max_results // 15),
        days: ($input.days // 3),
        tone_filter: ($input.tone_filter // null),
        brand_safe_only: ($input.brand_safe_only // true),
        preferences: $prefs
    }')

# --- Call News API ---
RESPONSE=$(curl -s --max-time 30 \
    --request POST \
    --url "${NEWS_API_URL}/news" \
    --header "X-API-Key: ${OVERTONE_NEWS_API_KEY}" \
    --header "Content-Type: application/json" \
    --data "$REQUEST")

# --- Output ---
if echo "$RESPONSE" | jq empty 2>/dev/null; then
    echo "$RESPONSE" | jq '.'
else
    echo "Error: Unexpected response from News API"
    echo "$RESPONSE"
    exit 1
fi
