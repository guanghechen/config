# Print an optspec for argparse to handle cmd's options that are independent of any subcommand.
function __fish_acm_global_optspecs
    string join \n h/help V/version
end

function __fish_acm_needs_command
    # Figure out if the current invocation already has a command.
    set -l cmd (commandline -opc)
    set -e cmd[1]
    argparse -s (__fish_acm_global_optspecs) -- $cmd 2>/dev/null
    or return
    if set -q argv[1]
        # Also print the command, so this can be used to figure out what it is.
        echo $argv[1]
        return 1
    end
    return 0
end

function __fish_acm_using_subcommand
    set -l cmd (__fish_acm_needs_command)
    test -z "$cmd"
    and return 1
    contains -- $cmd[1] $argv
end

complete -c acm -n "__fish_acm_needs_command" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_needs_command" -s V -l version -d 'Print version'
complete -c acm -n "__fish_acm_needs_command" -f -a "test" -d 'Run sample → fixtures tests on a problem dir'
complete -c acm -n "__fish_acm_needs_command" -f -a "stress" -d 'Stress a solution against a brute force with generated inputs'
complete -c acm -n "__fish_acm_needs_command" -f -a "bundle" -d 'Inline `@acm-std` into a submittable single file under `snapshot/`'
complete -c acm -n "__fish_acm_needs_command" -f -a "leetcode" -d 'LeetCode operations (fetch / new / login / whoami)'
complete -c acm -n "__fish_acm_needs_command" -f -a "codeforces" -d 'Codeforces operations (fetch / new / login / whoami)'
complete -c acm -n "__fish_acm_needs_command" -f -a "daily" -d 'Local practice / interview problems (scaffold only — no fetch/login)'
complete -c acm -n "__fish_acm_needs_command" -f -a "completions" -d 'Print a shell completion script, or `--write` to install it (fish)'
complete -c acm -n "__fish_acm_needs_command" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c acm -n "__fish_acm_using_subcommand test" -l lang -d 'Restrict to these languages (repeatable: `--lang cpp --lang rust`)' -r
complete -c acm -n "__fish_acm_using_subcommand test" -l eps -d 'Compare with floating tolerance ≤ 10^-N (absolute or relative)' -r
complete -c acm -n "__fish_acm_using_subcommand test" -l case -d 'Run only this case order' -r
complete -c acm -n "__fish_acm_using_subcommand test" -l draft -d 'Test `draft.*` instead of `solution.*`'
complete -c acm -n "__fish_acm_using_subcommand test" -l all -d 'Run every layer regardless of sample outcome'
complete -c acm -n "__fish_acm_using_subcommand test" -l no-cache -d 'Force a fresh compile, ignoring the artifact cache (e.g. after editing an `#include`d header, which the content hash does not track)'
complete -c acm -n "__fish_acm_using_subcommand test" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand stress" -l lang -r
complete -c acm -n "__fish_acm_using_subcommand stress" -l brute-lang -r
complete -c acm -n "__fish_acm_using_subcommand stress" -l gen-lang -r
complete -c acm -n "__fish_acm_using_subcommand stress" -l seed -r
complete -c acm -n "__fish_acm_using_subcommand stress" -l count -r
complete -c acm -n "__fish_acm_using_subcommand stress" -l time-budget -r
complete -c acm -n "__fish_acm_using_subcommand stress" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand bundle" -l lang -d 'Language to bundle; inferred when the dir has a single solution.* (or draft.*)' -r
complete -c acm -n "__fish_acm_using_subcommand bundle" -l draft -d 'Bundle `draft.*` instead of `solution.*`'
complete -c acm -n "__fish_acm_using_subcommand bundle" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and not __fish_seen_subcommand_from fetch new login whoami help" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "fetch" -d 'Fetch statement + samples into the problem dir (scaffolds it if absent)'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "new" -d 'Scaffold a new problem or contest for this OJ'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "login" -d 'Validate the stored session credential and report signed-in state'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "whoami" -d 'Show the signed-in user\'s basic info (username, premium, profile)'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -s p -l problem -d 'Standalone problem id (e.g. a LeetCode title-slug or Codeforces `1850A`)' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -s c -l contest -d 'Contest id' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l url -d 'A problem/contest URL for this OJ; problem vs contest is auto-detected (trailing path segments / query tolerated)' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l problems -d 'Problem indices within the contest, e.g. `A,B,C` (with `--contest`)' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l scope -d 'Disambiguate a bare numeric contest id (LeetCode: weekly vs biweekly)' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l lang -d 'Lay down `solution.<ext>` from the OJ\'s per-language template (repeatable: `--lang ts --lang cpp`). Omit to fetch metadata only; `[lang.template]` is recorded regardless' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l force -d 'Overwrite existing samples / author-filled meta fields'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l format -d 'Run prettier on the freshly-fetched sample/ + problem.md (overrides `[fetch] format`)'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l no-format -d 'Skip the post-fetch prettier pass even if `[fetch] format = true`'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l dressing -d 'Rewrite plain-text math in problem.md into inline MathJax via the LLM (`[translate]` endpoint; overrides `[fetch] dressing`). Runs before translate'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l no-dressing -d 'Skip the post-fetch math dressing even if `[fetch] dressing = true`'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l translate -d 'Translate a non-Chinese problem.md → problem-zh.md via the configured LLM (`[translate]`; overrides `[fetch] translate`). Best-effort — a failure warns only'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -l no-translate -d 'Skip the post-fetch translation even if `[fetch] translate = true`'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from fetch" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from new" -s p -l problem -d 'Standalone problem id (e.g. a LeetCode title-slug or Codeforces `1850A`)' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from new" -s c -l contest -d 'Contest id' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from new" -l url -d 'A problem/contest URL for this OJ; problem vs contest is auto-detected (trailing path segments / query tolerated)' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from new" -l problems -d 'Problem indices within the contest, e.g. `A,B,C` (with `--contest`)' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from new" -l scope -d 'Disambiguate a bare numeric contest id (LeetCode: weekly vs biweekly)' -r
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from new" -l fetch -d 'Fetch immediately after scaffolding'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from new" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from login" -l browser -d 'Acquire a fresh session by driving a browser (requires an acm built with `--features browser`) instead of validating the stored credential'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from login" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from whoami" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from help" -f -a "fetch" -d 'Fetch statement + samples into the problem dir (scaffolds it if absent)'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from help" -f -a "new" -d 'Scaffold a new problem or contest for this OJ'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from help" -f -a "login" -d 'Validate the stored session credential and report signed-in state'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from help" -f -a "whoami" -d 'Show the signed-in user\'s basic info (username, premium, profile)'
complete -c acm -n "__fish_acm_using_subcommand leetcode; and __fish_seen_subcommand_from help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and not __fish_seen_subcommand_from fetch new login whoami help" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "fetch" -d 'Fetch statement + samples into the problem dir (scaffolds it if absent)'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "new" -d 'Scaffold a new problem or contest for this OJ'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "login" -d 'Validate the stored session credential and report signed-in state'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "whoami" -d 'Show the signed-in user\'s basic info (username, premium, profile)'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and not __fish_seen_subcommand_from fetch new login whoami help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -s p -l problem -d 'Standalone problem id (e.g. a LeetCode title-slug or Codeforces `1850A`)' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -s c -l contest -d 'Contest id' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l url -d 'A problem/contest URL for this OJ; problem vs contest is auto-detected (trailing path segments / query tolerated)' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l problems -d 'Problem indices within the contest, e.g. `A,B,C` (with `--contest`)' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l scope -d 'Disambiguate a bare numeric contest id (LeetCode: weekly vs biweekly)' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l lang -d 'Lay down `solution.<ext>` from the OJ\'s per-language template (repeatable: `--lang ts --lang cpp`). Omit to fetch metadata only; `[lang.template]` is recorded regardless' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l force -d 'Overwrite existing samples / author-filled meta fields'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l format -d 'Run prettier on the freshly-fetched sample/ + problem.md (overrides `[fetch] format`)'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l no-format -d 'Skip the post-fetch prettier pass even if `[fetch] format = true`'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l dressing -d 'Rewrite plain-text math in problem.md into inline MathJax via the LLM (`[translate]` endpoint; overrides `[fetch] dressing`). Runs before translate'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l no-dressing -d 'Skip the post-fetch math dressing even if `[fetch] dressing = true`'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l translate -d 'Translate a non-Chinese problem.md → problem-zh.md via the configured LLM (`[translate]`; overrides `[fetch] translate`). Best-effort — a failure warns only'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -l no-translate -d 'Skip the post-fetch translation even if `[fetch] translate = true`'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from fetch" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from new" -s p -l problem -d 'Standalone problem id (e.g. a LeetCode title-slug or Codeforces `1850A`)' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from new" -s c -l contest -d 'Contest id' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from new" -l url -d 'A problem/contest URL for this OJ; problem vs contest is auto-detected (trailing path segments / query tolerated)' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from new" -l problems -d 'Problem indices within the contest, e.g. `A,B,C` (with `--contest`)' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from new" -l scope -d 'Disambiguate a bare numeric contest id (LeetCode: weekly vs biweekly)' -r
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from new" -l fetch -d 'Fetch immediately after scaffolding'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from new" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from login" -l browser -d 'Acquire a fresh session by driving a browser (requires an acm built with `--features browser`) instead of validating the stored credential'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from login" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from whoami" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from help" -f -a "fetch" -d 'Fetch statement + samples into the problem dir (scaffolds it if absent)'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from help" -f -a "new" -d 'Scaffold a new problem or contest for this OJ'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from help" -f -a "login" -d 'Validate the stored session credential and report signed-in state'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from help" -f -a "whoami" -d 'Show the signed-in user\'s basic info (username, premium, profile)'
complete -c acm -n "__fish_acm_using_subcommand codeforces; and __fish_seen_subcommand_from help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c acm -n "__fish_acm_using_subcommand daily; and not __fish_seen_subcommand_from new help" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand daily; and not __fish_seen_subcommand_from new help" -f -a "new" -d 'Scaffold a local problem or contest (meta + empty sample slot + solution skeletons)'
complete -c acm -n "__fish_acm_using_subcommand daily; and not __fish_seen_subcommand_from new help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c acm -n "__fish_acm_using_subcommand daily; and __fish_seen_subcommand_from new" -s p -l problem -d 'Problem name (e.g. `two-pointers`) → `oj/daily/problem/<name>`' -r
complete -c acm -n "__fish_acm_using_subcommand daily; and __fish_seen_subcommand_from new" -s c -l contest -d 'Contest name (e.g. `interview-google`) → `oj/daily/contest/<name>/…`' -r
complete -c acm -n "__fish_acm_using_subcommand daily; and __fish_seen_subcommand_from new" -l problems -d 'Problem indices within the contest, e.g. `A,B,C` (with `--contest`)' -r
complete -c acm -n "__fish_acm_using_subcommand daily; and __fish_seen_subcommand_from new" -l lang -d 'Lay down `solution.<ext>` skeletons for these languages (repeatable: `--lang cpp --lang ts`). Omit to use `[daily] lang` from acm.toml' -r
complete -c acm -n "__fish_acm_using_subcommand daily; and __fish_seen_subcommand_from new" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand daily; and __fish_seen_subcommand_from help" -f -a "new" -d 'Scaffold a local problem or contest (meta + empty sample slot + solution skeletons)'
complete -c acm -n "__fish_acm_using_subcommand daily; and __fish_seen_subcommand_from help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c acm -n "__fish_acm_using_subcommand completions" -l bash -d 'Emit a bash completion script'
complete -c acm -n "__fish_acm_using_subcommand completions" -l zsh -d 'Emit a zsh completion script'
complete -c acm -n "__fish_acm_using_subcommand completions" -l fish -d 'Emit a fish completion script'
complete -c acm -n "__fish_acm_using_subcommand completions" -l elvish -d 'Emit an elvish completion script'
complete -c acm -n "__fish_acm_using_subcommand completions" -l powershell -d 'Emit a PowerShell completion script'
complete -c acm -n "__fish_acm_using_subcommand completions" -l write -d 'Install the script into the shell\'s completion dir instead of printing to stdout (fish only: `$XDG_CONFIG_HOME/fish/completions/acm.fish`)'
complete -c acm -n "__fish_acm_using_subcommand completions" -s h -l help -d 'Print help'
complete -c acm -n "__fish_acm_using_subcommand help; and not __fish_seen_subcommand_from test stress bundle leetcode codeforces daily completions help" -f -a "test" -d 'Run sample → fixtures tests on a problem dir'
complete -c acm -n "__fish_acm_using_subcommand help; and not __fish_seen_subcommand_from test stress bundle leetcode codeforces daily completions help" -f -a "stress" -d 'Stress a solution against a brute force with generated inputs'
complete -c acm -n "__fish_acm_using_subcommand help; and not __fish_seen_subcommand_from test stress bundle leetcode codeforces daily completions help" -f -a "bundle" -d 'Inline `@acm-std` into a submittable single file under `snapshot/`'
complete -c acm -n "__fish_acm_using_subcommand help; and not __fish_seen_subcommand_from test stress bundle leetcode codeforces daily completions help" -f -a "leetcode" -d 'LeetCode operations (fetch / new / login / whoami)'
complete -c acm -n "__fish_acm_using_subcommand help; and not __fish_seen_subcommand_from test stress bundle leetcode codeforces daily completions help" -f -a "codeforces" -d 'Codeforces operations (fetch / new / login / whoami)'
complete -c acm -n "__fish_acm_using_subcommand help; and not __fish_seen_subcommand_from test stress bundle leetcode codeforces daily completions help" -f -a "daily" -d 'Local practice / interview problems (scaffold only — no fetch/login)'
complete -c acm -n "__fish_acm_using_subcommand help; and not __fish_seen_subcommand_from test stress bundle leetcode codeforces daily completions help" -f -a "completions" -d 'Print a shell completion script, or `--write` to install it (fish)'
complete -c acm -n "__fish_acm_using_subcommand help; and not __fish_seen_subcommand_from test stress bundle leetcode codeforces daily completions help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c acm -n "__fish_acm_using_subcommand help; and __fish_seen_subcommand_from leetcode" -f -a "fetch" -d 'Fetch statement + samples into the problem dir (scaffolds it if absent)'
complete -c acm -n "__fish_acm_using_subcommand help; and __fish_seen_subcommand_from leetcode" -f -a "new" -d 'Scaffold a new problem or contest for this OJ'
complete -c acm -n "__fish_acm_using_subcommand help; and __fish_seen_subcommand_from leetcode" -f -a "login" -d 'Validate the stored session credential and report signed-in state'
complete -c acm -n "__fish_acm_using_subcommand help; and __fish_seen_subcommand_from leetcode" -f -a "whoami" -d 'Show the signed-in user\'s basic info (username, premium, profile)'
complete -c acm -n "__fish_acm_using_subcommand help; and __fish_seen_subcommand_from codeforces" -f -a "fetch" -d 'Fetch statement + samples into the problem dir (scaffolds it if absent)'
complete -c acm -n "__fish_acm_using_subcommand help; and __fish_seen_subcommand_from codeforces" -f -a "new" -d 'Scaffold a new problem or contest for this OJ'
complete -c acm -n "__fish_acm_using_subcommand help; and __fish_seen_subcommand_from codeforces" -f -a "login" -d 'Validate the stored session credential and report signed-in state'
complete -c acm -n "__fish_acm_using_subcommand help; and __fish_seen_subcommand_from codeforces" -f -a "whoami" -d 'Show the signed-in user\'s basic info (username, premium, profile)'
complete -c acm -n "__fish_acm_using_subcommand help; and __fish_seen_subcommand_from daily" -f -a "new" -d 'Scaffold a local problem or contest (meta + empty sample slot + solution skeletons)'
