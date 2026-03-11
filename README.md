# scala-claudebox

[![Build & Publish](https://github.com/jchapuis/scala-claudebox/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/jchapuis/scala-claudebox/actions/workflows/docker-publish.yml)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A fork of [claudebox](https://github.com/RchGrav/claudebox) that adds a Scala development profile. Run Claude Code in an isolated Docker container with JDK 21, sbt, Metals MCP, and your host MCP servers bridged in.

## What's included

| Component | Version | Notes |
|-----------|---------|-------|
| JDK | 21 (Eclipse Temurin) | Via Adoptium apt repo |
| sbt | 1.10.7 | Pre-warmed with Scala 3.6.4 compiler |
| Coursier | latest | Native on x86_64, JVM launcher on ARM64 |
| Metals MCP | 1.6.6 | Started automatically as HTTP background process |
| scalafmt | latest | Via Coursier |
| scalafix | latest | Via Coursier |
| Node.js, git, Python/uv, zsh, tmux, gh, delta | from claudebox base | |

## Installation

Clone this repo and create a symlink to the CLI:

```bash
git clone https://github.com/jchapuis/scala-claudebox.git
cd scala-claudebox

# Option A: symlink to ~/.local/bin (make sure it's in your PATH)
mkdir -p ~/.local/bin
ln -sf "$PWD/main.sh" ~/.local/bin/claudebox

# Option B: build the self-extracting installer
bash .builder/build.sh
./dist/claudebox.run
```

## Usage

`cd` into your Scala project and use the claudebox CLI:

```bash
cd ~/projects/my-scala-app

# First time: add the scala profile
claudebox profile scala

# Launch Claude Code
claudebox
```

That's it. The CLI builds the Docker image (with caching), mounts your project as `/workspace`, starts Metals MCP on the workspace, and drops you into Claude Code.

### Passing arguments to Claude Code

```bash
# Continue a previous conversation
claudebox -c

# Use a specific model
claudebox --model opus

# Save default flags so you don't type them every time
claudebox save --disable-firewall
```

### Host MCP server bridging

MCP servers configured on your host (`~/.claude.json`) are automatically passed through to the container. To also bridge the [Kapture](https://github.com/nichochar/kapture) browser extension:

```bash
# Auto-detect Kapture SSE port and pass it in
KAPTURE_PORT=$(scripts/kapture-detect.sh 2>/dev/null || true) claudebox
```

Your host Claude Code skills, commands, plugins, and settings are mounted into the container automatically.

### Shell access

```bash
# Open a zsh shell in the container (without starting Claude Code)
claudebox shell
```

## Alternative: use the pre-built Docker image directly

If you prefer not to install the CLI, a pre-built image is published on each push to main:

```bash
docker run -it --rm \
  -v "$PWD:/workspace" \
  -e ANTHROPIC_API_KEY \
  ghcr.io/jchapuis/scala-claudebox:latest
```

For the full experience with host config, MCP bridging, and Kapture:

```bash
docker run -it --rm \
  --add-host=host.docker.internal:host-gateway \
  -v "$PWD:/workspace" \
  -v "$HOME/.claude/skills:/home/claude/.claudebox/skills:ro" \
  -v "$HOME/.claude/commands:/home/claude/.claudebox/commands:ro" \
  -v "$HOME/.claude/plugins:/home/claude/.claudebox/plugins:ro" \
  -v "$HOME/.claude/settings.json:/home/claude/.claudebox/host-settings.json:ro" \
  -v "$HOME/.claude/config.json:/home/claude/.claudebox/host-config.json:ro" \
  -v "$HOME/.gitconfig:/home/claude/.gitconfig:ro" \
  -v "$HOME/.ssh:/home/claude/.ssh:ro" \
  -e ANTHROPIC_API_KEY \
  -e KAPTURE_PORT \
  ghcr.io/jchapuis/scala-claudebox:latest
```

## Environment variables

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `ANTHROPIC_API_KEY` | Yes | - | Claude Code API access |
| `ENABLE_METALS` | No | `true` | Start Metals MCP server on `/workspace` |
| `METALS_PORT` | No | `7101` | Metals MCP HTTP listen port |
| `ENABLE_KAPTURE` | No | `true` | Register Kapture MCP (requires `KAPTURE_PORT`) |
| `KAPTURE_PORT` | No | - | Kapture SSE port on the host |
| `GITHUB_TOKEN` | No | - | GitHub CLI authentication |

## MCP servers

| Server | Transport | Where | Activation |
|--------|-----------|-------|------------|
| **metals-mcp** | HTTP (Streamable) | Inside container | Automatic on startup (port 7101) |
| **kapture** | SSE | Host, bridged via `host.docker.internal` | Set `KAPTURE_PORT` env var |
| **context7, serena, sequential-thinking** | stdio | Host `~/.claude.json` passthrough | Configure on host, claudebox passes through |

## Building the image locally

```bash
bash scripts/build-scala.sh claudebox-scala:local
```

## Upstream claudebox documentation

This fork includes all upstream claudebox features (profiles, multi-instance, firewall, tmux, etc.). See below for details.

---

## claudebox features

### Default Flags Management

Save your preferred security flags to avoid typing them every time:

```bash
# Save default flags
claudebox save --enable-sudo --disable-firewall

# Clear saved flags
claudebox save

# Now all claudebox commands will use your saved flags automatically
claudebox  # Will run with sudo and firewall disabled
```

### Project Information

View comprehensive information about your ClaudeBox setup:

```bash
# Show detailed project and system information
claudebox info
```

The info command displays:
- **Current Project**: Path, ID, and data directory
- **ClaudeBox Installation**: Script location and symlink
- **Saved CLI Flags**: Your default flags configuration
- **Claude Commands**: Global and project-specific custom commands
- **Project Profiles**: Installed profiles, packages, and available options
- **Docker Status**: Image status, creation date, layers, running containers
- **All Projects Summary**: Total projects, images, and Docker system usage

### Package Management

```bash
# Install additional packages (project-specific)
claudebox install htop vim tmux

# Open a powerline zsh shell in the container
claudebox shell

# Update Claude CLI
claudebox update

# View/edit firewall allowlist
claudebox allowlist
```

### Tmux Integration

ClaudeBox provides tmux support for multi-pane workflows:

```bash
# Launch ClaudeBox with tmux support
claudebox tmux

# If you're already in a tmux session, the socket will be automatically mounted
# Otherwise, tmux will be available inside the container

# Use tmux commands inside the container:
# - Create new panes: Ctrl+b % (vertical) or Ctrl+b " (horizontal)
# - Switch panes: Ctrl+b arrow-keys  
# - Create new windows: Ctrl+b c
# - Switch windows: Ctrl+b n/p or Ctrl+b 0-9
```

ClaudeBox automatically detects and mounts existing tmux sockets from the host, or provides tmux functionality inside the container for powerful multi-context workflows.

### Task Engine

ClaudeBox contains a compact task engine for reliable code generation tasks:

```bash
# In Claude, use the task command
/task

# This provides a systematic approach to:
# - Breaking down complex tasks
# - Implementing with quality checks
# - Iterating until specifications are met
```

### Security Options

```bash
# Run with sudo enabled (use with caution)
claudebox --enable-sudo

# Disable network firewall (allows all network access)
claudebox --disable-firewall

# Skip permission checks
claudebox --dangerously-skip-permissions
```

### Maintenance

```bash
# Interactive clean menu
claudebox clean

# Project-specific cleanup options
claudebox clean --project          # Shows submenu with options:
  # profiles - Remove profile configuration (*.ini file)
  # data     - Remove project data (auth, history, configs, firewall)
  # docker   - Remove project Docker image
  # all      - Remove everything for this project

# Global cleanup options
claudebox clean --containers       # Remove ClaudeBox containers
claudebox clean --image           # Remove containers and current project image
claudebox clean --cache           # Remove Docker build cache
claudebox clean --volumes         # Remove ClaudeBox volumes
claudebox clean --all             # Complete Docker cleanup

# Rebuild the image from scratch
claudebox rebuild
```

## 🔧 Configuration

ClaudeBox stores data in:
- `~/.claude/` - Global Claude configuration (mounted read-only)
- `~/.claudebox/` - Global ClaudeBox data
- `~/.claudebox/profiles/` - Per-project profile configurations (*.ini files)
- `~/.claudebox/<project-name>/` - Project-specific data:
  - `.claude/` - Project auth state
  - `.claude.json` - Project API configuration
  - `.zsh_history` - Shell history
  - `.config/` - Tool configurations
  - `firewall/allowlist` - Network allowlist
- Current directory mounted as `/workspace` in container

### Project-Specific Features

Each project automatically gets:
- **Docker Image**: `claudebox-<project-name>` with installed profiles
- **Profile Configuration**: `~/.claudebox/profiles/<project-name>.ini`
- **Python Virtual Environment**: `.venv` created with uv when Python profile is active
- **Firewall Allowlist**: Customizable per-project network access rules
- **Claude Configuration**: Project-specific `.claude.json` settings

### Environment Variables

- `ANTHROPIC_API_KEY` - Your Anthropic API key
- `NODE_ENV` - Node environment (default: production)

## 🏗️ Architecture

ClaudeBox creates a per-project Debian-based Docker image with:
- Node.js (via NVM for version flexibility)
- Claude Code CLI (@anthropic-ai/claude-code)
- User account matching host UID/GID
- Network firewall (project-specific allowlists)
- Volume mounts for workspace and configuration
- GitHub CLI (gh) for repository operations
- Delta for enhanced git diffs (version 0.17.0)
- uv for fast Python package management
- Nala for improved apt package management
- fzf for fuzzy finding
- zsh with oh-my-zsh and powerline theme
- Profile-specific development tools with intelligent layer caching
- Persistent project state (auth, history, configs)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🐛 Troubleshooting

### Docker Permission Issues
ClaudeBox automatically handles Docker setup, but if you encounter issues:
1. The script will add you to the docker group
2. You may need to log out/in or run `newgrp docker`
3. Run `claudebox` again

### Profile Installation Failed
```bash
# Clean and rebuild for current project
claudebox clean --project
claudebox rebuild
claudebox profile <name>
```

### Profile Changes Not Taking Effect
ClaudeBox automatically detects profile changes and rebuilds when needed. If you're having issues:
```bash
# Force rebuild
claudebox rebuild
```

### Python Virtual Environment Issues
ClaudeBox automatically creates a venv when Python profile is active:
```bash
# The venv is created at ~/.claudebox/<project>/.venv
# It's automatically activated in the container
claudebox shell
which python  # Should show the venv python
```

### Can't Find Command
Ensure the symlink was created:
```bash
ls -la ~/.local/bin/claudebox
# Or manually create it
ln -s /path/to/claudebox ~/.local/bin/claudebox
```

### Multiple Instance Conflicts
Each project has its own Docker image and is fully isolated. To check status:
```bash
# Check all ClaudeBox images and containers
claudebox info

# Clean project-specific data
claudebox clean --project
```

### Build Cache Issues
If builds are slow or failing:
```bash
# Clear Docker build cache
claudebox clean --cache

# Complete cleanup and rebuild
claudebox clean --all
claudebox
```

## 🎉 Acknowledgments

- [Anthropic](https://www.anthropic.com/) for Claude AI
- [Model Context Protocol](https://github.com/anthropics/model-context-protocol) for MCP servers
- Docker community for containerization tools
- All the open-source projects included in the profiles

---

Made with ❤️ for developers who love clean, reproducible environments

## Contact

**Author/Maintainer:** RchGrav  
**GitHub:** [@RchGrav](https://github.com/RchGrav)
