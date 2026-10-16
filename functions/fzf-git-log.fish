# Upstream reference: https://github.com/PatrickF1/fzf.fish/blob/main/functions/_fzf_search_git_log.fish
# Locally adapted; see README.md for sync policy.

function fzf-git-log --description "Search git log and insert commit hash"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo 'fzf-git-log: Not in a git repository.' >&2
        commandline --function repaint
        return 1
    end

    set -l format '%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset)%C(auto)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)'
    # The preview moves below the list when a side panel would be narrower than 120 columns,
    # leaving room for delta's side-by-side layout.
    set -l selected (
        git log --graph --no-show-signature --color=always --format=format:$format --date=short |
        fzf --ansi --multi --no-sort --scheme=history --prompt="Git Log> " \
            --with-shell='fish --no-config -c' --bind=ctrl-o:ignore \
            --preview='
                # Graph-only lines carry no commit hash.
                set -l hash (string match --regex --groups-only -- "^[^0-9a-f]*([0-9a-f]{4,})" {}); or exit
                set -l show git show --color=always --unified=5 --stat --stat-count=5 --patch \
                    --date="format:%Y-%m-%d %H:%M:%S" \
                    --format="%C(bold blue)%h%C(reset)%C(auto)%d%C(reset)%n%C(dim)%an <%ae>%C(reset)  %C(cyan)%ad%C(reset) %C(dim)(%ar)%C(reset)%n%n%C(bold)%s%C(reset)%n%n%-b"
                # alt-w sets the preview label, which doubles as the ignore-whitespace state.
                test -n "$FZF_PREVIEW_LABEL"; and set -a show --ignore-all-space
                if command -q delta
                    # delta renders at a fixed width; narrow previews use the unified layout.
                    test $FZF_PREVIEW_COLUMNS -lt 100; and set -lx DELTA_FEATURES +unified
                    $show $hash | delta --width=$FZF_PREVIEW_COLUMNS
                else
                    $show $hash
                end
            ' \
            --preview-window='right,60%,<120(down,60%)' \
            --bind='ctrl-/:change-preview-window(90%,<120(down,90%)|)+refresh-preview' \
            --bind='alt-w:transform-preview-label(test -n "$FZF_PREVIEW_LABEL"; or echo " ignore whitespace ")+refresh-preview' \
            --bind=resize:refresh-preview \
            --query=(commandline --current-token)
    )

    if test $status -eq 0
        set -l hashes
        for line in $selected
            set -l abbrev (string match --regex --groups-only -- '^[^0-9a-f]*([0-9a-f]{4,})' $line); or continue
            set -a hashes (git rev-parse $abbrev)
        end
        set -q hashes[1]; and commandline --current-token --replace -- (string join ' ' $hashes)
    end

    commandline --function repaint
end
