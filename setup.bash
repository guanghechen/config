#!/usr/bin/env bash
# Setup script for ~/.config/bash configuration
# Idempotent: safe to run multiple times

set -euo pipefail

BASH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bash"

# Marker comments for idempotent insertion
MARKER_PROFILE="# >>> bash-config >>>"
MARKER_BASHRC="# >>> bash-config >>>"

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

# Inject content into file if marker not present
inject_config() {
    local file="$1"
    local marker="$2"
    local content="$3"
    local prepend="${4:-false}"

    if [[ -f "$file" ]] && grep -qF "$marker" "$file"; then
        echo "[skip] $file already configured"
        return
    fi

    if [[ "$prepend" == "true" ]]; then
        if [[ -f "$file" ]]; then
            local existing
            existing=$(cat "$file")
            printf '%s\n\n%s\n' "$content" "$existing" > "$file"
        else
            printf '%s\n' "$content" > "$file"
        fi
    else
        printf '\n%s\n' "$content" >> "$file"
    fi
    echo "[done] $file configured"
}

# Setup ~/.bash_profile
inject_config "$HOME/.bash_profile" "$MARKER_PROFILE" "$BASH_PROFILE_CONTENT" true

# Setup ~/.bashrc
inject_config "$HOME/.bashrc" "$MARKER_BASHRC" "$BASHRC_CONTENT" true

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
