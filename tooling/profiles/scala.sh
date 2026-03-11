#!/bin/bash
set -euo pipefail

# Check if info argument is provided
if [ "${1:-}" = "info" ]; then
    echo "Scala"
    echo "Scala Development (JDK 21, sbt, Coursier, Metals, scalafmt, scalafix)"
    exit 0
fi

export COURSIER_BIN="$HOME/.local/share/coursier/bin"
export PATH="$COURSIER_BIN:$PATH"

# Install Coursier if not present
if [ ! -f "$COURSIER_BIN/cs" ]; then
    echo "Installing Coursier..."
    curl -fL "https://github.com/coursier/coursier/releases/latest/download/cs-$(uname -m)-pc-linux.gz" \
      | gzip -d > /tmp/cs && chmod +x /tmp/cs
    /tmp/cs setup --yes --install-dir "$COURSIER_BIN" --apps metals,scalafmt,scalafix 2>/dev/null
    rm -f /tmp/cs
fi

# Verify tools
echo "Scala toolchain:"
echo "  java:     $(java -version 2>&1 | head -1)"
echo "  sbt:      $(sbt --version 2>&1 | tail -1)"
echo "  cs:       $(cs version 2>&1)"
echo "  metals:   $(which metals 2>/dev/null && echo 'installed' || echo 'not found')"
echo "  scalafmt:  $(scalafmt --version 2>&1 || echo 'not found')"
echo "  scalafix:  $(scalafix --version 2>&1 || echo 'not found')"

echo "Scala development environment ready"
