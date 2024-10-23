## Change the git prompt style
## See https://fishshell.com/docs/current/cmds/fish_git_prompt.html
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
set -g __fish_git_prompt_color_untrackedfiles     $fish_color_normal
set -g __fish_git_prompt_show_informative_status  true
set -g __fish_git_prompt_showdirtystate           true
set -g __fish_git_prompt_showstashstate           true
set -g __fish_git_prompt_showuntrackedfiles       true
set -g __fish_git_prompt_showupstream             informative

function fish_prompt --description 'Write out the prompt'
  set -l last_pipestatus $pipestatus
  set -lx __fish_last_status $status # Export for __fish_print_pipestatus.

  set -l color_cwd
  set -l suffix
  set -l user_separator
  if functions -q fish_is_root_user; and fish_is_root_user
    if set -q fish_color_cwd_root
      set color_cwd $color_red
    else
      set color_cwd $color_blue
    end
    set suffix '#'
    set user_separator '#'
  else
    set color_cwd $color_blue
    set suffix '$'
    set user_separator '@'
  end

  # PWD
  set -l pwd $PWD
  if not test -w $pwd
    set_color $color_red
    echo -n ' '
  end

  set_color $color_red
  echo -n (whoami)

  set_color $color_aqua
  echo -n $user_separator

  set_color $color_fg
  printf "%s " (hostname)

  set -l pwd (string replace -r "^$HOME" "~" $pwd)
  set_color $color_cwd
  echo -n  $pwd

  set_color $color_fg
  printf '%s ' (fish_vcs_prompt)

  set -l status_color (set_color $fish_color_status)
  set -l statusb_color (set_color --bold $fish_color_status)
  set -l prompt_status (__fish_print_pipestatus "[" "]" "|" "$status_color" "$statusb_color" $last_pipestatus)
  echo -n $prompt_status

  # current time
  set -l current_time (date "+%H:%M:%S")
  set_color $fg4
  printf '%s ' $current_time
  set_color normal

  printf "\n  %s " $suffix
end
