## Local
#
# set -gx f_windows_terminal_settings
#
# set -gx AZURE_OPENAI_O4_MINI_ENDPOINT     '<endpoint>'
# set -gx AZURE_OPENAI_O4_MINI_DEPLOYMENT   o4-mini
# set -gx AZURE_OPENAI_O4_MINI_MODEL        o4-mini
# set -gx AZURE_OPENAI_O4_MINI_API_KEY      <api-key>
# set -gx AZURE_OPENAI_O4_MINI_API_VERSION  2024-12-01-preview
# 
# set -gx AZURE_OPENAI_ENDPOINT     (echo $AZURE_OPENAI_O4_MINI_ENDPOINT)
# set -gx AZURE_OPENAI_DEPLOYMENT   (echo $AZURE_OPENAI_O4_MINI_DEPLOYMENT)
# set -gx AZURE_OPENAI_MODEL        (echo $AZURE_OPENAI_O4_MINI_MODEL)
# set -gx AZURE_OPENAI_API_KEY      (echo $AZURE_OPENAI_O4_MINI_API_KEY)
# set -gx AZURE_OPENAI_API_VERSION  (echo $AZURE_OPENAI_O4_MINI_API_VERSION)
# set -gx AZURE_API_BASE            (echo $AZURE_OPENAI_O4_MINI_ENDPOINT)
# set -gx AZURE_API_VERSION         (echo $AZURE_OPENAI_O4_MINI_API_VERSION)
#
# set -gx YOZORA_WORKSPACE_BLOCK
# set -gx YOZORA_WORKSPACE_NOTE
#
if test -f "$HOME/.config/fish/local/config.fish"
    source "$HOME/.config/fish/local/config.fish"
end
