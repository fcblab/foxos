#!/bin/bash
set -euo pipefail

# Update existing configuration from the current environment; restore the T3 template first.
# TOML roundtripping requires go-yq >= 4.52.1.
export CODEX_BASE_URL="${CODEX_BASE_URL:-}"
export CODEX_AUTH_TOKEN="${CODEX_AUTH_TOKEN:-}"
export CODEX_MODEL="${CODEX_MODEL:-gpt-6.2-sol}"
export CODEX_THINKING_LEVEL="${CODEX_THINKING_LEVEL:-medium}"
export CC_BASE_URL="${CC_BASE_URL:-}"
export CC_AUTH_TOKEN="${CC_AUTH_TOKEN:-}"
export CC_MODEL="${CC_MODEL:-claude-opus-5-5[1m]}"
export CC_THINKING_LEVEL="${CC_THINKING_LEVEL:-medium}"

mkdir -p ~/.t3/userdata
cp ~/.config/foxos/t3.json ~/.t3/userdata/settings.json

yq -i -p toml -o toml '
  .model_providers.custom.base_url = strenv(CODEX_BASE_URL) |
  .model_providers.custom.experimental_bearer_token = strenv(CODEX_AUTH_TOKEN) |
  .model = strenv(CODEX_MODEL) |
  .model_reasoning_effort = strenv(CODEX_THINKING_LEVEL)
' ~/.codex/config.toml

yq -i -p json -o json '
  .env.ANTHROPIC_BASE_URL = strenv(CC_BASE_URL) |
  .env.ANTHROPIC_AUTH_TOKEN = strenv(CC_AUTH_TOKEN) |
  .model = strenv(CC_MODEL) |
  .modelSettings = {} |
  .modelSettings[(strenv(CC_MODEL) | sub("\\[1m\\]$"; ""))].effortLevel = strenv(CC_THINKING_LEVEL)
' ~/.claude/settings.json

yq -i '
  .modelRoles.default = ("custom/" + strenv(CODEX_MODEL)) |
  .defaultThinkingLevel = strenv(CODEX_THINKING_LEVEL)
' ~/.omp/agent/config.yml

yq -i '
  .providers.custom.baseUrl = strenv(CODEX_BASE_URL) |
  .providers.custom.apiKey = strenv(CODEX_AUTH_TOKEN)
' ~/.omp/agent/models.yml

yq -i -p json -o json '
  .defaultModelSelection.model = strenv(CODEX_MODEL) |
  (.defaultModelSelection.options[] | select(.id == "reasoningEffort").value) = strenv(CODEX_THINKING_LEVEL) |
  .fallbackModelSelection.model = (strenv(CC_MODEL) | sub("\\[1m\\]$"; ""))
' ~/.t3/userdata/settings.json
