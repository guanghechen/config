#!/usr/bin/env bash
# Setup script for ~/.config/bash configuration
# Idempotent: safe to run multiple times

set -euo pipefail

BASH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bash"

# Marker comments for idempotent insertion
MARKER_START="# >>> bash-config >>>"
MARKER_END="# <<< bash-config <<<"

# Content to insert
read -r -d '' BASH_PROFILE_CONTENT << 'EOF' || true
# >>> bash-config >>>
[[ -n "$__BASH_PROFILE_LOADED" ]] && return
export __BASH_PROFILE_LOADED=1
[[ -f ~/.config/bash/profile.bash ]] && source ~/.config/bash/profile.bash
[[ -f ~/.bashrc ]] && source ~/.bashrc
# <<< bash-config <<<
EOF

read -r -d '' BASHRC_CONTENT << 'EOF' || true
# >>> bash-config >>>
[[ $- != *i* ]] && return
[[ -n "$__BASHRC_LOADED" ]] && return
export __BASHRC_LOADED=1
[[ -f ~/.config/bash/bashrc.bash ]] && source ~/.config/bash/bashrc.bash
# <<< bash-config <<<
EOF

# Extract existing block between markers
extract_block() {
    local file="$1"
    sed -n "/$MARKER_START/,/$MARKER_END/p" "$file" 2>/dev/null || true
}

# Remove existing block between markers
remove_block() {
    local file="$1"
    local tmp="${file}.tmp.$$"
    sed "/$MARKER_START/,/$MARKER_END/d" "$file" > "$tmp" && mv "$tmp" "$file"
}

# Inject or update config block
inject_config() {
    local file="$1"
    local content="$2"

    if [[ -f "$file" ]]; then
        local existing
        existing=$(extract_block "$file")
        if [[ "$existing" == "$content" ]]; then
            echo "[skip] $file already up-to-date"
            return
        fi
        if [[ -n "$existing" ]]; then
            remove_block "$file"
            echo "[update] $file block replaced"
        fi
        # Prepend to existing content
        local rest
        rest=$(cat "$file")
        printf '%s\n\n%s\n' "$content" "$rest" > "$file"
    else
        printf '%s\n' "$content" > "$file"
    fi
    echo "[done] $file configured"
}

# Setup ~/.bash_profile
inject_config "$HOME/.bash_profile" "$BASH_PROFILE_CONTENT"

# Setup ~/.bashrc
inject_config "$HOME/.bashrc" "$BASHRC_CONTENT"

# Setup local/env.bash
LOCAL_ENV="$BASH_CONFIG_DIR/local/env.bash"
if [[ -f "$LOCAL_ENV" ]]; then
    echo "[skip] $LOCAL_ENV already exists"
else
    mkdir -p "$BASH_CONFIG_DIR/local"
    cp "$BASH_CONFIG_DIR/samples/env.bash" "$LOCAL_ENV"
    echo "[done] $LOCAL_ENV created from sample"
fi

echo ""
echo "Setup complete. Restart your shell or run:"
echo "  source ~/.bash_profile"
