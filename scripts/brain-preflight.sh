#!/usr/bin/env bash
set -euo pipefail

ports=(
  8000
  9000
  10200
  10300
  11434
  3000
  3001
  6333
  8888
)

echo "Chimera Brain preflight: checking for port conflicts..."
conflicts=0

for port in "${ports[@]}"; do
  if ss -lntp 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"; then
    echo "Port ${port} is already in use."
    conflicts=$((conflicts + 1))
  else
    echo "Port ${port} is free."
  fi
done

if [[ "${conflicts}" -gt 0 ]]; then
  echo "Preflight failed: ${conflicts} port conflict(s) detected."
  exit 1
fi

echo "Preflight OK: no port conflicts detected."
