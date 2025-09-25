function ghc-claude-local
    set -l port_override ""

    for arg in $argv
        if string match -q -- "--port=*" $arg
            set port_override (string split "=" -- $arg)[2]
            break
        end
    end

    set -l api_port $GHC_COPILOT_API_PORT
    if test -n "$port_override"
        set api_port $port_override
    end

    set -ge ANTHROPIC_API_KEY
    set -gx ANTHROPIC_BASE_URL "http://$GHC_COPILOT_API_HOST:$api_port"
    set -gx ANTHROPIC_AUTH_TOKEN $GHC_ANTHROPIC_AUTH_TOKEN
    set -gx ANTHROPIC_MODEL claude-sonnet-4
    set -gx ANTHROPIC_SMALL_FAST_MODEL claude-3.7-sonnet

    if test -n "$port_override"
        echo "Claude api switched to $ANTHROPIC_BASE_URL"
    end
end
