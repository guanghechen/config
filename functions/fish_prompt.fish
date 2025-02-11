## Change the git prompt style
## See https://fishshell.com/docs/current/cmds/fish_git_prompt.html
#
set -g __fish_git_prompt_char_cleanstate          ''
set -g __fish_git_prompt_char_dirtystate          '●'
set -g __fish_git_prompt_char_invalidstate        '✗'
set -g __fish_git_prompt_char_stagedstate         '+'
set -g __fish_git_prompt_char_untrackedfiles      '?'
set -g __fish_git_prompt_color_branch             magenta   --bold
set -g __fish_git_prompt_color_cleanstate         green     --bold
set -g __fish_git_prompt_color_dirtystate         yellow
set -g __fish_git_prompt_color_invalidstate       red
set -g __fish_git_prompt_color_stagedstate        blue
set -g __fish_git_prompt_color_untrackedfiles     normal
set -g __fish_git_prompt_show_informative_status  true
set -g __fish_git_prompt_showdirtystate           true
set -g __fish_git_prompt_showstashstate           true
set -g __fish_git_prompt_showuntrackedfiles       true
set -g __fish_git_prompt_showupstream             informative

function fish_prompt --description 'Write out the prompt'
  set -l last_pipestatus $pipestatus
  set -lx __fish_last_status $status # Export for __fish_print_pipestatus.

  set -l suffix
  set -l user_separator
  if functions -q fish_is_root_user; and fish_is_root_user
    set suffix          '#'
    set user_separator  '#'
  else
    set suffix          '$'
    set user_separator  '@'
  end

  # PWD
  set -l pwd $PWD

  set_color red --bold
  echo -n (whoami)

  set_color white
  echo -n $user_separator

  set_color cyan
  printf "%s " (hostname)

  set -l text_pwd (string replace -r "^$HOME" "~" $pwd)
  if test -w $pwd
    set_color blue
    echo -n $text_pwd
  else
    set_color brred
    echo -n "󰌾 "

    set_color red
    echo -n $text_pwd
  end

  set_color brwhite
  printf '%s ' (fish_vcs_prompt)

  set -l status_color (set_color brred)
  set -l statusb_color (set_color brred --bold)
  set -l prompt_status (__fish_print_pipestatus "[" "]" "|" "$status_color" "$statusb_color" $last_pipestatus)
  echo -n $prompt_status

  # current time
  set -l current_time (date "+%H:%M:%S")
  set_color white
  printf '%s ' $current_time

  if set -q CONDA_DEFAULT_ENV
    set_color green
    printf '(%s) ' $CONDA_DEFAULT_ENV
  end

  set_color brcyan
  printf "\n  %s " $suffix

  set_color normal
end
