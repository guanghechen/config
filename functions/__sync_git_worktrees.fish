function __sync_git_worktrees --argument-names reporoot repomain repo_url reponame scope
    set branches $argv[6..]

    if not test -d "$reporoot"
        printf "\e[94m   [$reponame] mkdir -p %s\e[0m\n" "$reporoot"
        mkdir -p "$reporoot"
        printf "\n"
    end

    if test "$scope" = main
        if test -d "$repomain/.git"
            printf "\e[94m   [$reponame] fetching and merging origin/$branches[1]\e[0m\n"
            git -C $repomain fetch origin
            git -C $repomain merge origin/$branches[1] --ff-only
            printf "\n"
        else
            printf "\e[94m   [$reponame] cloning $repo_url (branch: $branches[1])\e[0m\n"
            git clone $repo_url --branch=$branches[1] $repomain
            printf "\n"
        end
    else
        set is_required (test "$scope" = required; and echo true; or echo false)

        for branch in $branches
            set repopath "$reporoot/$branch"

            if test -d "$repopath"
                printf "\e[94m   [$reponame] syncing $branch\e[0m\n"
                git -C "$repopath" merge origin/$branch --ff-only
                printf "\n"
            else if test "$is_required" = true
                printf "\e[94m   [$reponame] add new worktree of $branch\e[0m\n"
                git -C "$repomain" worktree add "$repopath" $branch
                printf "\n"
            end
        end
    end
end
