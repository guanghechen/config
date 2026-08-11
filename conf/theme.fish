# Use below command to show all available terminal colors.
#
# set_color --print-colors
#

# Core syntax highlighting
set -g  fish_color_command                       brblue
set -g  fish_color_keyword                       brmagenta
set -g  fish_color_param                         cyan
set -g  fish_color_option                        green
set -g  fish_color_quote                         brgreen
set -g  fish_color_redirection                   brmagenta
set -g  fish_color_end                           bryellow
set -g  fish_color_operator                      yellow

# Interactive elements
set -g  fish_color_autosuggestion                brblack
set -g  fish_color_completion                    normal
set -g  fish_color_comment                       brblack
set -g  fish_color_gray                          brblack

# Status and feedback
set -g  fish_color_error                         brred
set -g  fish_color_status                        red
set -g  fish_color_cancel                        --reverse
set -g  fish_color_escape                        cyan
set -g  fish_color_normal                        normal
set -g  fish_color_dir                           brblue
set -g  fish_color_valid_path                    --underline

# Search and selection
set -g  fish_color_search_match                  --background=brorange
set -g  fish_color_search_selection              --background=brblue
set -g  fish_color_match                         --background=brblue
set -g  fish_color_history_current               --bold

# Remote host
set -g  fish_color_host_remote                   yellow

# Pager colors
set -g  fish_pager_color_background              normal
set -g  fish_pager_color_completion              normal
set -g  fish_pager_color_description             yellow
set -g  fish_pager_color_prefix                  cyan --bold
set -g  fish_pager_color_progress                brwhite --background=blue
set -g  fish_pager_color_secondary_background    normal
set -g  fish_pager_color_secondary_completion    brblack
set -g  fish_pager_color_secondary_description   brblack
set -g  fish_pager_color_secondary_prefix        brblack
set -g  fish_pager_color_selected_background     --background=blue
set -g  fish_pager_color_selected_completion     brwhite
set -g  fish_pager_color_selected_description    brwhite
set -g  fish_pager_color_selected_prefix         brwhite
