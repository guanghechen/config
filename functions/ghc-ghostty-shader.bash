# shellcheck shell=bash
# ghc-ghostty-shader - Toggle or set Ghostty shader

ghc-ghostty-shader() {
    local silent=false prev=false
    local OPTIND opt
    while getopts "spn-:" opt; do
        case $opt in
            s) silent=true ;;
            p) prev=true ;;
            n) ;;  # next is default behavior, no-op
            -)
                case "${OPTARG}" in
                    silent) silent=true ;;
                    prev) prev=true ;;
                    next) ;;  # next is default behavior, no-op
                    *) echo "Unknown option --${OPTARG}" >&2; return 1 ;;
                esac
                ;;
            *) return 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    local shaders=(
        off
        cubes
        cubes-light
        fireworks-rockets
        gears-and-belts
        inside-the-matrix
        matrix-hallway
        mnoise
        sparks-from-fire
        starfield
    )

    local config_dir="$HOME/.config/ghostty/local"
    local config_path="$config_dir/shader.conf"
    mkdir -p "$config_dir"

    local shader_name
    if [[ $# -eq 0 ]]; then
        local current="off"
        if [[ -f "$config_path" ]]; then
            local matched
            matched=$(grep -oE 'shaders/(.+)\.glsl' "$config_path" | sed 's|shaders/||;s|\.glsl||' | tail -1)
            [[ -n "$matched" ]] && current="$matched"
        fi

        local idx=-1
        for i in "${!shaders[@]}"; do
            if [[ "${shaders[$i]}" == "$current" ]]; then
                idx=$i
                break
            fi
        done

        local max=${#shaders[@]}
        if $prev; then
            if [[ $idx -le 0 ]]; then
                shader_name="${shaders[$((max - 1))]}"
            else
                shader_name="${shaders[$((idx - 1))]}"
            fi
        else
            if [[ $idx -eq -1 || $idx -eq $((max - 1)) ]]; then
                shader_name="${shaders[0]}"
            else
                shader_name="${shaders[$((idx + 1))]}"
            fi
        fi
    else
        shader_name="$1"
    fi

    if [[ "$shader_name" == "off" ]]; then
        : > "$config_path"
        $silent || printf "\e[96m  Shader disabled\e[0m\n"
    else
        echo "custom-shader = ../shaders/$shader_name.glsl" > "$config_path"
        $silent || printf "\e[92m  Shader: %s\e[0m\n" "$shader_name"
    fi

    pkill -USR2 ghostty
}
