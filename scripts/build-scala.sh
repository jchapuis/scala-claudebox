#!/usr/bin/env bash
# Build claudebox with Scala profile directly
# Usage: ./scripts/build-scala.sh [image-name]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="${1:-claudebox-scala:local}"

# Use current user's UID/GID
USER_ID=$(id -u)
GROUP_ID=$(id -g)
USERNAME="claude"
NODE_VERSION="--lts"
DELTA_VERSION="0.18.2"

# Create build context
BUILD_CTX=$(mktemp -d)
trap "rm -rf $BUILD_CTX" EXIT

cp "$REPO_DIR/build/docker-entrypoint" "$BUILD_CTX/docker-entrypoint.sh"
cp "$REPO_DIR/build/init-firewall" "$BUILD_CTX/init-firewall"
cp "$REPO_DIR/build/generate-tools-readme" "$BUILD_CTX/generate-tools-readme"
cp "$REPO_DIR/lib/tools-report.sh" "$BUILD_CTX/tools-report.sh"
cp "$REPO_DIR/build/dockerignore" "$BUILD_CTX/.dockerignore"
chmod +x "$BUILD_CTX/docker-entrypoint.sh" "$BUILD_CTX/init-firewall" "$BUILD_CTX/generate-tools-readme"

# Read base Dockerfile
BASE_DF=$(cat "$REPO_DIR/build/Dockerfile")

# Generate core profile installations
CORE_PACKAGES="gcc g++ make git pkg-config libssl-dev libffi-dev zlib1g-dev tmux"
CORE_INSTALL="RUN apt-get update && apt-get install -y $CORE_PACKAGES && apt-get clean"

# Generate scala profile installations (read from heredoc to avoid shell expansion issues)
SCALA_INSTALL=$(cat <<'SCALA_PROFILE'
# --- Scala profile: JDK 21 + sbt + Coursier + Metals/scalafmt/scalafix ---
USER root

# JDK 21 via Eclipse Temurin
RUN apt-get update && \
    apt-get install -y --no-install-recommends gnupg && \
    curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
      | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/adoptium.gpg] \
      https://packages.adoptium.net/artifactory/deb bookworm main" \
      > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends temurin-21-jdk && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# sbt
RUN curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" \
      | gpg --dearmor -o /usr/share/keyrings/sbt-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/sbt-archive-keyring.gpg] \
      https://repo.scala-sbt.org/scalasbt/debian all main" \
      > /etc/apt/sources.list.d/sbt.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends sbt && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Coursier + Scala CLI tools (as claude user)
USER claude
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
      curl -fL "https://github.com/coursier/coursier/releases/latest/download/cs-x86_64-pc-linux.gz" \
        | gzip -d > /tmp/cs && chmod +x /tmp/cs; \
    else \
      curl -fL "https://github.com/coursier/coursier/releases/latest/download/coursier" -o /tmp/cs && chmod +x /tmp/cs; \
    fi && \
    /tmp/cs setup --yes --install-dir "$HOME/.local/share/coursier/bin" \
      --apps metals,metals-mcp,scalafmt,scalafix 2>/dev/null && \
    rm -f /tmp/cs

# sbt warmup: pre-download launcher + Scala 3 compiler
RUN mkdir -p /tmp/sbt-warmup/project /tmp/sbt-warmup/src/main/scala && \
    echo 'scalaVersion := "3.6.4"' > /tmp/sbt-warmup/build.sbt && \
    echo 'sbt.version=1.10.7' > /tmp/sbt-warmup/project/build.properties && \
    echo 'object Warmup' > /tmp/sbt-warmup/src/main/scala/Warmup.scala && \
    cd /tmp/sbt-warmup && sbt compile </dev/null && \
    cd / && rm -rf /tmp/sbt-warmup

USER root

# Set JAVA_HOME
RUN echo "export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-$(dpkg --print-architecture)" >> /etc/profile.d/java.sh && \
    echo "export PATH=/home/claude/.local/share/coursier/bin:\$PATH" >> /etc/profile.d/coursier.sh
ENV PATH="/home/claude/.local/share/coursier/bin:$PATH"
SCALA_PROFILE
)

LABELS='LABEL claudebox.profiles="scala"
LABEL claudebox.project="scala-claudebox"'

# Combine profile installations
PROFILE_INSTALLATIONS="$CORE_INSTALL
$SCALA_INSTALL"

# Write profile installations and labels to temp files for sed
PROFILE_FILE=$(mktemp)
LABELS_FILE=$(mktemp)
printf '%s' "$PROFILE_INSTALLATIONS" > "$PROFILE_FILE"
printf '%s' "$LABELS" > "$LABELS_FILE"

# Replace placeholders using sed with file insertion
# First write the base Dockerfile
printf '%s' "$BASE_DF" > "$BUILD_CTX/Dockerfile"

# Replace {{PROFILE_INSTALLATIONS}} with profile content
python3 -c "
import sys
with open('$BUILD_CTX/Dockerfile') as f:
    content = f.read()
with open('$PROFILE_FILE') as f:
    profiles = f.read()
with open('$LABELS_FILE') as f:
    labels = f.read()
content = content.replace('{{PROFILE_INSTALLATIONS}}', profiles)
content = content.replace('{{LABELS}}', labels)
with open('$BUILD_CTX/Dockerfile', 'w') as f:
    f.write(content)
"

rm -f "$PROFILE_FILE" "$LABELS_FILE"

echo "=== Building $IMAGE_NAME ==="
echo "Build context: $BUILD_CTX"

export DOCKER_BUILDKIT=1
docker build \
    --progress=auto \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --build-arg USER_ID="$USER_ID" \
    --build-arg GROUP_ID="$GROUP_ID" \
    --build-arg USERNAME="$USERNAME" \
    --build-arg NODE_VERSION="$NODE_VERSION" \
    --build-arg DELTA_VERSION="$DELTA_VERSION" \
    -f "$BUILD_CTX/Dockerfile" \
    -t "$IMAGE_NAME" \
    "$BUILD_CTX"

echo "=== Build complete: $IMAGE_NAME ==="
