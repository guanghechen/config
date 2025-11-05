function ghc-neovim-nightly
    set -l ps_cmd "ps aux"
    if test (uname) = Linux
        set ps_cmd "ps -aux"
    end

    set -l nvim_processes (eval $ps_cmd | grep nvim | grep -v grep)

    if test -n "$nvim_processes"
        set_color yellow
        echo "⚠️  Neovim processes are currently running:"
        set_color normal
        echo ""

        echo "$nvim_processes"

        echo ""
        set_color red
        echo "Please close all Neovim instances or kill the processes before continuing."
        set_color normal
        set_color cyan
        set -l pids (echo "$nvim_processes" | awk '{print $2}' | string join ' ')
        echo "You can kill them with: kill $pids"
        set_color normal
        return 1
    end

    if not set -q NEOVIM_HOME
        set_color red
        echo "❌ Error: NEOVIM_HOME environment variable is not set"
        set_color normal
        return 1
    end

    set_color blue --bold
    echo "📦 Building Neovim nightly..."
    set_color normal
    echo ""

    set_color cyan
    echo "→ Fetching tags and checking out nightly branch..."
    set_color normal
    git fetch origin --tags --force && git checkout nightly; or return 1

    echo ""
    set_color cyan
    echo "→ Building with CMake (RelWithDebInfo)..."
    set_color normal
    make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$NEOVIM_HOME"; or return 1

    echo ""
    set_color cyan
    echo "→ Removing old installation..."
    set_color normal
    rm -rf "$NEOVIM_HOME"; or return 1

    echo ""
    set_color cyan
    echo "→ Installing to $NEOVIM_HOME..."
    set_color normal
    make install; or return 1

    echo ""
    set_color green --bold
    echo "✅ Neovim nightly installed successfully!"
    set_color normal
end
