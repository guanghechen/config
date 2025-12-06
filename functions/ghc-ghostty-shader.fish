function ghc-ghostty-shader
    argparse 's/silent' -- $argv
    or return 1

    set -l shaders \
        off \
        cubes \
        fireworks-rockets \
        gears-and-belts \
        inside-the-matrix \
        sparks-from-fire \
        starfield \
        starfield-colors

    set config_dir "$HOME/.config/ghostty/local"
    set config_path "$config_dir/shader.conf"
    mkdir -p "$config_dir"

    if test (count $argv) -eq 0
        set -l current off
        if test -f "$config_path"
            set -l matched (string match -r 'shaders/(.+)\.glsl' < "$config_path" | tail -1)
            if test -n "$matched"
                set current $matched
            end
        end

        set -l idx 0
        for i in (seq (count $shaders))
            if test "$shaders[$i]" = "$current"
                set idx $i
                break
            end
        end

        if test $idx -eq 0 -o $idx -eq (count $shaders)
            set shader_name $shaders[1]
        else
            set shader_name $shaders[(math $idx + 1)]
        end
    else
        set shader_name $argv[1]
    end

    if test "$shader_name" = off
        echo -n >"$config_path"
        test -z "$_flag_silent"; and echo "Shader disabled"
    else
        echo "custom-shader = ../shaders/$shader_name.glsl" >"$config_path"
        test -z "$_flag_silent"; and echo "Shader: $shader_name"
    end

    pkill -USR2 ghostty
end
