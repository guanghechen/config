ghc-profile() {
  local __script
  __script="$(kit profile --shell=bash "$@")" || return $?
  eval "$__script"
}
