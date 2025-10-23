function ghc-update
    set reporoot "$HOME/.config"
    set repomain "$reporoot/guanghechen"
    set repo_url "https://github.com/guanghechen/config.git"
    set reponame config
    set main_branch guanghechen

    set required_branches fish
    set optional_branches \
        alacritty \
        alacritty-windows \
        bat \
        btop \
        claude \
        codex \
        conda \
        fzf \
        gh \
        ghostty \
        git-delta \
        helix \
        kitty \
        komorebi \
        lazygit \
        lsd \
        neovide \
        nvim \
        nvim-lazy \
        nvim-nvchad \
        ora \
        plan \
        pm2 \
        pwsh \
        ripgrep \
        skhd \
        tmux \
        tsuki \
        wezterm \
        yabai \
        yasb \
        yazi \
        yoz

    printf "\e[92m  [$repomain] syncing...\e[0m\n"
    __sync_git_worktrees $reporoot $repomain $repo_url $reponame main $main_branch
    __sync_git_worktrees $reporoot $repomain $repo_url $reponame required $required_branches
    __sync_git_worktrees $reporoot $repomain $repo_url $reponame optional $optional_branches
    printf "\e[96m  [$reponame] done.\e[0m\n\n"

    #----------------------------------------------------------------------------------------------#

    set reporoot "$HOME/wiki"
    set repomain "$reporoot/wiki"
    set repo_url "https://github.com/guanghechen/wiki.git"
    set reponame wiki
    set main_branch wiki

    set required_branches translator wiki-note
    set optional_branches

    printf "\e[92m  [$repomain] syncing...\e[0m\n"
    __sync_git_worktrees $reporoot $repomain $repo_url $reponame main $main_branch
    __sync_git_worktrees $reporoot $repomain $repo_url $reponame required $required_branches
    __sync_git_worktrees $reporoot $repomain $repo_url $reponame optional $optional_branches
    printf "\e[96m  [$reponame] done.\e[0m\n"
end
