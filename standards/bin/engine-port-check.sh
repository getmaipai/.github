#!/usr/bin/env bash
# Reject scripts that launch a local engine on one of Home's fixed default ports.
set -uo pipefail
ROOT="${1:-.}"
cd "$ROOT"
STATUS=0

while IFS= read -r file; do
  [ -f "$file" ] || continue
  # Ignore comments and prose. A launch is an executable process-spawn
  # expression naming an engine, paired with a literal default port.
  if awk '
    /^[[:space:]]*(#|\/\/|\/\*|\*)/ { next }
    {
      line=tolower($0)
      if (line ~ /(spawn|exec|command)[^;]*(llama-server|pocket-tts|whisper)/ || line ~ /(llama-server|pocket-tts|whisper)[^;]*(spawn|exec)/) launch=1
      if (line ~ /(^|[[:space:]"'"'"'])[^[:space:]]*(llama-server|pocket-tts|whisper)([[:space:]]|$)/ || line ~ /\$llama([[:space:]]|$)/) launch=1
      if (line ~ /(--port|port)[^0-9]*(8788|8789|8793|8794)([^0-9]|$)/) fixed=1
    }
    END { exit !(launch && fixed) }
  ' "$file"; then
    echo "fixed default engine port in launching script: $file"
    STATUS=1
  fi
done < <(git ls-files --cached | awk '/(^|\/)(scripts|bench)(\/|$)/ && /\.(sh|bash|ts|tsx|js|mjs|cjs|py)$/ { print }')

if [ "$STATUS" -eq 0 ]; then
  echo "engine-port-check: no fixed default engine ports in scripts"
fi
exit "$STATUS"
