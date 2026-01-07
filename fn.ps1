## Lazy load helper
function __lazy_load__ {
  param([string]$FuncName)
  $filePath = "$env:XDG_CONFIG_HOME\pwsh\functions\f_$FuncName.ps1"
  . $filePath
  & "f_$FuncName" @args
}

## Lazy loaded functions
function ghc-claude-remote { __lazy_load__ 'ghc-claude-remote' @args }
function ghc-opensource { __lazy_load__ 'ghc-opensource' @args }
function ghc-patch-claude { __lazy_load__ 'ghc-patch-claude' @args }
function ghc-proxy { __lazy_load__ 'ghc-proxy' @args }
function ghc-theme-apply { __lazy_load__ 'ghc-theme-apply' @args }
function ghc-theme-gen { __lazy_load__ 'ghc-theme-gen' @args }
function ghc-theme-toggle { __lazy_load__ 'ghc-theme-toggle' @args }
function ghc-update { __lazy_load__ 'ghc-update' @args }
function ghc-upgrade { __lazy_load__ 'ghc-upgrade' @args }
function swap-alt-win { __lazy_load__ 'swap-alt-win' @args }
function yoz { __lazy_load__ 'yoz' @args }
