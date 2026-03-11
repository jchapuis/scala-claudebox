#!/usr/bin/env bash
# Detect the Kapture MCP SSE port on the host
# Usage: source this or run it; prints the port number on success

set -euo pipefail

for port in 3025 3000 9222 9229 8080; do
  if curl -sf "http://localhost:${port}/sse" --max-time 1 -o /dev/null 2>&1; then
    echo "$port"
    exit 0
  fi
done

echo "Kapture MCP port not auto-detected" >&2
exit 1
