function ghc-show-resource
    if test (count $argv) -eq 0
        echo "Usage: ghc-show-resource <process_name>"
        return 1
    end

    set proc_name $argv[1]

    # Collect all data first
    set pids (pgrep $proc_name)
    set all_data

    for pid in $pids
        set threads (ps -M -p $pid | wc -l | string trim)
        set fds (lsof -p $pid | wc -l | string trim)
        set cmd (ps -p $pid -o command=)
        set cwd (lsof -p $pid -a -d cwd -F n 2>/dev/null | grep '^n' | cut -c2- | head -n1)

        set all_data $all_data "$pid|$threads|$fds|$cmd|$cwd"
    end

    # Calculate column widths
    set pid_width 3
    set threads_width 7
    set fds_width 3
    set cmd_width 7

    for data in $all_data
        set fields (string split "|" $data)
        set pid_len (string length $fields[1])
        set threads_len (string length $fields[2])
        set fds_len (string length $fields[3])
        set cmd_len (string length $fields[4])

        if test $pid_len -gt $pid_width
            set pid_width $pid_len
        end
        if test $threads_len -gt $threads_width
            set threads_width $threads_len
        end
        if test $fds_len -gt $fds_width
            set fds_width $fds_len
        end
        if test $cmd_len -gt $cmd_width
            set cmd_width $cmd_len
        end
    end

    # Print table header with calculated widths and 3-space gaps
    set header_format "%-"(math $pid_width + 3)"s%-"(math $threads_width + 3)"s%-"(math $fds_width + 3)"s%-"(math $cmd_width + 3)"s%s\n"
    printf $header_format PID Threads FDs Command CWD

    # Print data rows
    set data_format "%-"(math $pid_width + 3)"s%-"(math $threads_width + 3)"s%-"(math $fds_width + 3)"s%-"(math $cmd_width + 3)"s%s\n"
    for data in $all_data
        set fields (string split "|" $data)
        printf $data_format $fields[1] $fields[2] $fields[3] $fields[4] $fields[5]
    end
end
