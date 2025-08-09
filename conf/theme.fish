# Use below command to show all available terminal colors.
#
# set_color --print-colors
#

# Core syntax highlighting
set -U  fish_color_command                       brblue
set -U  fish_color_keyword                       brmagenta
set -U  fish_color_param                         cyan
set -U  fish_color_option                        green
set -U  fish_color_quote                         brgreen
set -U  fish_color_redirection                   brmagenta
set -U  fish_color_end                           bryellow
set -U  fish_color_operator                      yellow

# Interactive elements
set -U  fish_color_autosuggestion                brblack
set -U  fish_color_completion                    normal
set -U  fish_color_comment                       brblack
set -U  fish_color_gray                          brblack

# Status and feedback
set -U  fish_color_error                         brred
set -U  fish_color_status                        red
set -U  fish_color_cancel                        --reverse
set -U  fish_color_escape                        cyan
set -U  fish_color_normal                        normal
set -U  fish_color_dir                           brblue
set -U  fish_color_valid_path                    --underline

# Search and selection
set -U  fish_color_search_match                  --background=brorange
set -U  fish_color_search_selection              --background=brblue
set -U  fish_color_match                         --background=brblue
set -U  fish_color_history_current               --bold

# Remote host
set -U  fish_color_host_remote                   yellow

# Pager colors
set -U  fish_pager_color_background              normal
set -U  fish_pager_color_completion              normal
set -U  fish_pager_color_description             yellow
set -U  fish_pager_color_prefix                  cyan --bold
set -U  fish_pager_color_progress                brwhite --background=blue
set -U  fish_pager_color_secondary_background    normal
set -U  fish_pager_color_secondary_completion    brblack
set -U  fish_pager_color_secondary_description   brblack
set -U  fish_pager_color_secondary_prefix        brblack
set -U  fish_pager_color_selected_background     --background=blue
set -U  fish_pager_color_selected_completion     brwhite
set -U  fish_pager_color_selected_description    brwhite
set -U  fish_pager_color_selected_prefix         brwhite
