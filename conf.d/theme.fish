if test -f "$HOME/.config/fish/theme/local.fish"
  source "$HOME/.config/fish/theme/local.fish"
else
  source ~/.config/fish/theme/gruvbox_light.fish
end

set -gx fish_color_autosuggestion     $color_fg4
set -gx fish_color_command            $color_blue
set -gx fish_color_comment            $color_fg4
set -gx fish_color_date               $color_fg4
set -gx fish_color_error              $color_neutral_red
set -gx fish_color_gray               $color_fg4
set -gx fish_color_match              $color_orange
set -gx fish_color_normal             $color_fg
set -gx fish_color_param              $color_aqua
