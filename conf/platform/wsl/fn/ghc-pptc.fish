function ghc-pptc -d "Copy PPT file to Windows Downloads/ppt folder"
    if not set -q GHC_WINDOWS_USERNAME; or test -z "$GHC_WINDOWS_USERNAME"
        echo "Error: GHC_WINDOWS_USERNAME is not set"
        echo "Please set it in your fish config: set -gx GHC_WINDOWS_USERNAME 'your_windows_username'"
        return 1
    end

    set -l win_home "/mnt/c/Users/$GHC_WINDOWS_USERNAME"

    if not test -d "$win_home"
        echo "Error: Windows home directory not found at $win_home"
        echo "Please check if GHC_WINDOWS_USERNAME ('$GHC_WINDOWS_USERNAME') is correct"
        return 1
    end

    set -l path $argv[1]

    if test -z "$path"
        echo "Usage: ghc-pptc <path>"
        return 1
    end

    # Extract the datetime piece from path (e.g., "20250918_160228")
    set -l datetime_match (string match -r '(\d{8}_\d{6})' $path)
    if test -z "$datetime_match"
        echo "Error: Cannot extract datetime from path: $path"
        return 1
    end

    set -l v_datetime $datetime_match[2]
    set -l v_date (string sub -l 8 $v_datetime)
    set -l v_time (string sub -s 10 $v_datetime)

    # Extract original filename
    set -l filename (basename $path)

    # Create target directory
    set -l target_dir "$win_home/Downloads/ppt/$v_date"
    mkdir -p $target_dir

    # Create target filename
    set -l target_file "$target_dir/$v_time-$filename"

    # Copy file
    cp $path $target_file

    echo "Copied $path to $target_file"
end
