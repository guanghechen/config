function ghc-show-port
    if test (count $argv) -eq 0
        echo "Usage: ghc-show-port <port>"
        return 1
    end

    set port $argv[1]

    # Validate port number
    if not string match -qr '^\d+$' $port
        echo "Error: Port must be a number"
        return 1
    end

    # Collect all data first
    set all_data

    # Use lsof to find processes listening on the port
    set lsof_lines (lsof -i :$port -n -P 2>/dev/null | string split \n)

    if test (count $lsof_lines) -le 1
        echo "No processes found listening on port $port"
        return 0
    end

    # Skip the header line and process each line
    for i in (seq 2 (count $lsof_lines))
        set line $lsof_lines[$i]
        if test -z "$line"
            continue
        end

        # Parse lsof output with proper field handling
        set fields (string split -n ' ' $line | string match -v '')
        set command $fields[1]
        set pid $fields[2]
        set user $fields[3]
        set fd $fields[4]
        set type $fields[5]
        set device $fields[6]
        set size $fields[7]
        set node $fields[8]
        set name $fields[9]

        # Get additional process info
        set cpu_mem (ps -p $pid -o %cpu,%mem 2>/dev/null | tail -n 1 | string trim | string replace -a ' ' ',')
        set cmd_full (ps -p $pid -o command= 2>/dev/null | string trim)
        set cwd (lsof -p $pid -a -d cwd -F n 2>/dev/null | grep '^n' | cut -c2- | head -n1)

        # Handle cases where fields might be empty
        if test -z "$cpu_mem"
            set cpu_mem "N/A"
        end
        if test -z "$cmd_full"
            set cmd_full "N/A"
        end
        if test -z "$cwd"
            set cwd "N/A"
        end

        set all_data $all_data "$command|$pid|$user|$name|$cpu_mem|$cmd_full|$cwd"
    end

    # Calculate column widths
    set command_width 7
    set pid_width 3
    set user_width 4
    set name_width 7
    set cpu_mem_width 8

    for data in $all_data
        set fields (string split "|" $data)
        set command_len (string length $fields[1])
        set pid_len (string length $fields[2])
        set user_len (string length $fields[3])
        set name_len (string length $fields[4])
        set cpu_mem_len (string length $fields[5])

        if test $command_len -gt $command_width
            set command_width $command_len
        end
        if test $pid_len -gt $pid_width
            set pid_width $pid_len
        end
        if test $user_len -gt $user_width
            set user_width $user_len
        end
        if test $name_len -gt $name_width
            set name_width $name_len
        end
        if test $cpu_mem_len -gt $cpu_mem_width
            set cpu_mem_width $cpu_mem_len
        end
    end

    # Print table header with calculated widths and 3-space gaps
    set header_format "%-"(math $command_width + 3)"s%-"(math $pid_width + 3)"s%-"(math $user_width + 3)"s%-"(math $name_width + 3)"s%-"(math $cpu_mem_width + 3)"s%-30s%s\n"
    printf $header_format Command PID User Address "CPU,MEM" "Full Command" CWD

    # Print data rows
    set data_format "%-"(math $command_width + 3)"s%-"(math $pid_width + 3)"s%-"(math $user_width + 3)"s%-"(math $name_width + 3)"s%-"(math $cpu_mem_width + 3)"s%-30s%s\n"
    for data in $all_data
        set fields (string split "|" $data)
        # Truncate long command if necessary
        set cmd_display $fields[6]
        if test (string length $cmd_display) -gt 30
            set cmd_display (string sub -l 27 $cmd_display)...
        end
        printf $data_format $fields[1] $fields[2] $fields[3] $fields[4] $fields[5] $cmd_display $fields[7]
    end
end