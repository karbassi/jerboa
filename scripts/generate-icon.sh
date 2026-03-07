#!/usr/bin/env bash
set -euo pipefail

API_KEY=$(op read "op://homelab/AI Assistant/Google AI Studio/api_key")
export GEMINI_API_KEY="$API_KEY"
export NANOBANANA_GEMINI_API_KEY="$API_KEY"
export NANOBANANA_GOOGLE_API_KEY="$API_KEY"
export GOOGLE_API_KEY="$API_KEY"

PROMPT='/icon "A cute stylized jerboa (small desert rodent with very large round ears, big dark shiny eyes, round body, long curved tail, large hind feet) holding a small white document with a blue Markdown M symbol. Semi-3D glossy style, soft top lighting. White/cream colored, pink inner ears. Dark charcoal-to-black gradient squircle background. Modern macOS Big Sur app icon style. Blue-to-cyan gradient accents. Polished glossy finish." --sizes="1024" --type="app-icon" --style="modern" --background="black" --corners="rounded"'

gemini --allowed-tools generate_icon -p "$PROMPT"
