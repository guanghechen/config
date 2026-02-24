function ghc-profile --description 'Load env from kit profile'
  kit profile --shell=fish $argv | source
end
