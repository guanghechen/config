if test -f "$HOME/.config/fish/local/theme.fish"
  source "$HOME/.config/fish/local/theme.fish"
else
  source ~/.config/fish/theme/gruvbox_light.fish
end

set -U black                                    $color_bg0
set _U red                                      $color_neutral_red
set _U green                                    $color_neutral_green
set _U yellow                                   $color_neutral_yellow
set _U blue                                     $color_neutral_blue
set _U magenta                                  $color_neutral_purple
set _U cyan                                     $color_neutral_aqua
set _U white                                    $color_fg4
set -U brblack                                  $color_grey
set _U brred                                    $color_red
set _U brgreen                                  $color_green
set _U bryellow                                 $color_yellow
set _U brblue                                   $color_blue
set _U brmagenta                                $color_purple
set _U brcyan                                   $color_aqua
set _U brwhite                                  $color_fg

set -U fish_color_autosuggestion                $color_fg4
set -U fish_color_command                       $color_blue
set -U fish_color_comment                       $color_fg4
set -U fish_color_cancel                        --reverse
set -U fish_color_date                          $color_grey
set -U fish_color_end                           $color_orange
set -U fish_color_error                         $color_neutral_red
set -U fish_color_escape                        $color_aqua
set -U fish_color_gray                          $color_fg4
set -U fish_color_history_current               --bold
set -U fish_color_host_remote                   ''
set -U fish_color_keyword                       ''
set -U fish_color_operator                      $color_yellow
set -U fish_color_option                        ''
set -U fish_color_quote                         $color_green
set -U fish_color_match                         $color_orange
set -U fish_color_normal                        $color_fg
set -U fish_color_param                         $color_aqua
set -U fish_color_redirection                   $color_purple
set -U fish_color_search_match                  --background=$color_yellow
set -U fish_color_search_selection              --background=$color_yellow
set -U fish_color_status                        $color_red
set -U fish_color_valid_path                    --underline
set -U fish_pager_color_background              ''
set -U fish_pager_color_completion              normal
set -U fish_pager_color_description             $fg3
set -U fish_pager_color_prefix                  normal --bold --underline
set -U fish_pager_color_progress                brwhite --background=cyan
set -U fish_pager_color_secondary_background    ''
set -U fish_pager_color_secondary_completion    ''
set -U fish_pager_color_secondary_description   ''
set -U fish_pager_color_secondary_prefix        ''
set -U fish_pager_color_selected_background     --background=$color_yellow
set -U fish_pager_color_selected_completion     ''
set -U fish_pager_color_selected_description    ''
set -U fish_pager_color_selected_prefix         ''
