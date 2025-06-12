#!/usr/bin/env bash

# Advanced interactive backup script with AI assistance.
# This script allows the user to select directories for backup and consults a
# local AI model via HTTP during the process.

set -euo pipefail

DEFAULT_API_BASE="http://localhost:12000"
read -rp "Enter AI API base URL [${DEFAULT_API_BASE}]: " API_BASE
API_BASE="${API_BASE:-$DEFAULT_API_BASE}"
API_URL="${API_BASE%/}/api/chat"
CHAT_ID="$(uuidgen)"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

check_api() {
  local health
  health=$(curl -fs "$API_BASE/health" 2>/dev/null || true)
  if [[ -n "$health" ]]; then
    local models
    models=$(echo "$health" | jq -r '.supportedModels[]?' 2>/dev/null | xargs)
    if [[ -n "$models" ]]; then
      log "AI API healthy. Supported models: $models"
    else
      log "AI API responded, but models list unavailable"
    fi
  else
    log "Warning: could not contact AI API at $API_BASE"
  fi
}

# Check connectivity to the chosen AI API
check_api

# -----------------------------------------------------------------------------
# Helper: send a message to the AI endpoint and print the response
# -----------------------------------------------------------------------------
ask_ai() {
  local msg="$1"
  local payload
  payload=$(jq -n --arg msg "$msg" --arg chat "$CHAT_ID" '{messages:[{role:"user",content:$msg}],modelId:"meta-llama/Llama-3.3-70B-Instruct-Turbo",userSystemPrompt:"You are a helpful assistant",webSearchModePrompt:false,imageGenerationMode:false,chatId:$chat}')
  curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "$payload" | jq -r '.choices[0].message.content // ""'
}

# -----------------------------------------------------------------------------
# Gather user input
# -----------------------------------------------------------------------------
log "Welcome to the interactive backup script."
read -rp "Enter directories to backup (space-separated): " -a DIRS
read -rp "Enter destination archive path (e.g., /tmp/backup.tgz): " DEST

if [[ ${#DIRS[@]} -eq 0 || -z "$DEST" ]]; then
  echo "Error: directories and destination must be specified" >&2
  exit 1
fi

log "Consulting AI for backup advice..."
ask_ai "I plan to back up the following directories: ${DIRS[*]}. Suggest best practices for a reliable backup." || true

read -rp "Proceed with backup? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Backup aborted."
  exit 0
fi

# -----------------------------------------------------------------------------
# Perform the backup
# -----------------------------------------------------------------------------
log "Creating archive..."
mkdir -p "$(dirname "$DEST")"
tar czf "$DEST" "${DIRS[@]}"
log "Backup saved to $DEST"

log "Consulting AI for verification tips..."
ask_ai "Backup completed for directories: ${DIRS[*]}. Provide verification steps." || true

log "All done."
