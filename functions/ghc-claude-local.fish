function ghc-claude-local
    set -l port_override ""
    set -l model_override ""
    set -l default_model opus
    set -l default_model_version "4.5"

    for arg in $argv
        if string match -q -- "--port=*" $arg
            set port_override (string split "=" -- $arg)[2]
        else if string match -q -- "--model=*" $arg
            set model_override (string split "=" -- $arg)[2]
        end
    end

    set -l api_port $GHC_COPILOT_API_PORT
    if test -n "$port_override"
        set api_port $port_override
    end

    if test -z "$model_override"
        set model_override $default_model
    end

    set -l selected_model ""

    switch $model_override
        case opus
            set selected_model "claude-opus-$default_model_version"
        case sonnet
            set selected_model "claude-sonnet-$default_model_version"
        case '*'
            echo "Unsupported model '$model_override'. Use --model=opus or --model=sonnet"
            return 1
    end

    set -ge ANTHROPIC_API_KEY
    set -gx ANTHROPIC_BASE_URL "http://$GHC_COPILOT_API_HOST:$api_port"
    set -gx ANTHROPIC_AUTH_TOKEN $GHC_ANTHROPIC_AUTH_TOKEN
    set -gx ANTHROPIC_MODEL $selected_model
    set -gx ANTHROPIC_SMALL_FAST_MODEL "claude-sonnet-$default_model_version"

end
