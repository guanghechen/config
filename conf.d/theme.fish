if test -f "$HOME/.config/fish/local/theme.fish"
  source "$HOME/.config/fish/local/theme.fish"
else
  source ~/.config/fish/theme/gruvbox_light.fish
end

set -gx black                                    $color_bg0
set -gx red                                      $color_neutral_red
set -gx green                                    $color_neutral_green
set -gx yellow                                   $color_neutral_yellow
set -gx blue                                     $color_neutral_blue
set -gx magenta                                  $color_neutral_purple
set -gx cyan                                     $color_neutral_aqua
set -gx white                                    $color_fg4
set -gx brblack                                  $color_bg4
set -gx brred                                    $color_red
set -gx brgreen                                  $color_green
set -gx bryellow                                 $color_yellow
set -gx brblue                                   $color_blue
set -gx brmagenta                                $color_purple
set -gx brcyan                                   $color_aqua
set -gx brwhite                                  $color_fg

set -gx fish_color_autosuggestion                $color_fg4
set -gx fish_color_command                       $color_blue
set -gx fish_color_comment                       $color_fg4
set -gx fish_color_cancel                        --reverse
set -gx fish_color_date                          $color_fg4
set -gx fish_color_end                           $color_orange
set -gx fish_color_error                         $color_neutral_red
set -gx fish_color_escape                        $color_aqua
set -gx fish_color_gray                          $color_fg4
set -gx fish_color_history_current               --bold
set -gx fish_color_host_remote                   ''
set -gx fish_color_keyword                       ''
set -gx fish_color_operator                      $color_yellow
set -gx fish_color_option                        ''
set -gx fish_color_quote                         $color_green
set -gx fish_color_match                         $color_orange
set -gx fish_color_normal                        $color_fg
set -gx fish_color_param                         $color_aqua
set -gx fish_color_redirection                   $color_purple
set -gx fish_color_search_match                  --background=$color_yellow
set -gx fish_color_search_selection              --background=$color_yellow
set -gx fish_color_status                        $color_red
set -gx fish_color_valid_path                    --underline
set -gx fish_pager_color_background              ''
set -gx fish_pager_color_completion              normal
set -gx fish_pager_color_description             $fg3
set -gx fish_pager_color_prefix                  normal --bold --underline
set -gx fish_pager_color_progress                brwhite --background=cyan
set -gx fish_pager_color_secondary_background    ''
set -gx fish_pager_color_secondary_completion    ''
set -gx fish_pager_color_secondary_description   ''
set -gx fish_pager_color_secondary_prefix        ''
set -gx fish_pager_color_selected_background     --background=$color_yellow
set -gx fish_pager_color_selected_completion     ''
set -gx fish_pager_color_selected_description    ''
set -gx fish_pager_color_selected_prefix         ''
