#!/bin/sh
# Install the /write-as-me skill into Claude Code.
#
# Copies skill-template/SKILL.md to ~/.claude/skills/write-as-me/ with
# RHAPSODE_REPO substituted for this checkout's path. Re-run after moving
# the repo or pulling template updates. An existing modified install is
# backed up to SKILL.md.bak first.
#
# Usage: Tools/voice-profile/install-skill.sh
#        (or: make install-skill)
# Override the destination with SKILLS_DIR=<path> (mainly for testing).

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
template="$script_dir/skill-template/SKILL.md"

[ -f "$template" ] || { echo "error: template not found at $template" >&2; exit 1; }

# Fill in the repo path and strip the install-instructions comment —
# installed copies don't need installing.
rendered=$(sed -e "s|RHAPSODE_REPO|$repo_root|g" -e '/<!-- INSTALL:/,/-->/d' "$template")

install_to() {
    dest_dir="$1/write-as-me"
    dest="$dest_dir/SKILL.md"
    mkdir -p "$dest_dir"
    if [ -f "$dest" ] && [ "$rendered" != "$(cat "$dest")" ]; then
        cp "$dest" "$dest.bak"
        echo "backed up existing skill to $dest.bak"
    fi
    printf '%s\n' "$rendered" > "$dest"
    echo "installed: $dest"
}

# Claude Code and Codex use the same SKILL.md format; install wherever
# the agent's config directory exists. SKILLS_DIR overrides everything
# (single custom destination, mainly for testing).
if [ -n "${SKILLS_DIR:-}" ]; then
    install_to "$SKILLS_DIR"
else
    installed=0
    if [ -d "$HOME/.claude" ]; then
        install_to "$HOME/.claude/skills"; installed=1
    fi
    if [ -d "$HOME/.codex" ]; then
        install_to "$HOME/.codex/skills"; installed=1
    fi
    if [ "$installed" -eq 0 ]; then
        echo "error: neither ~/.claude nor ~/.codex found — is Claude Code or Codex installed?" >&2
        exit 1
    fi
fi

echo "repo path: $repo_root"
echo
echo "New agent sessions will pick it up. Build your voice pack first"
echo "if you haven't: see $script_dir/README.md"
