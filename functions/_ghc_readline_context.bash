_ghc_readline_context() {
    GHC_READLINE_BEFORE=${READLINE_LINE:0:READLINE_POINT}
    # shellcheck disable=SC2034 # Used by fzf-* widgets in other sourced files.
    GHC_READLINE_AFTER=${READLINE_LINE:READLINE_POINT}
    GHC_READLINE_TOKEN=${GHC_READLINE_BEFORE##*[[:space:]]}
    # shellcheck disable=SC2034 # Used by fzf-* widgets in other sourced files.
    GHC_READLINE_TOKEN_START=$(( ${#GHC_READLINE_BEFORE} - ${#GHC_READLINE_TOKEN} ))
}
