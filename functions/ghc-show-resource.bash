# shellcheck shell=bash
# ghc-show-resource - Show resource usage for processes by name

ghc-show-resource() {
    if [[ $# -eq 0 ]]; then
        printf "\e[93m  Usage: ghc-show-resource <process_name>\e[0m\n"
        return 1
    fi

    local proc_name="$1"

    # Collect all data first
    local -a pids=() all_data=()
    while IFS= read -r pid; do
        [[ -n "$pid" ]] && pids+=("$pid")
    done < <(pgrep "$proc_name")

    if [[ ${#pids[@]} -eq 0 ]]; then
        printf "\e[93m  No processes found for %s\e[0m\n" "$proc_name"
        return 0
    fi

    for pid in "${pids[@]}"; do
        local threads fds cmd cwd
        threads=$(ps -M -p "$pid" 2>/dev/null | wc -l | tr -d ' ')
        fds=$(lsof -p "$pid" 2>/dev/null | wc -l | tr -d ' ')
        cmd=$(ps -p "$pid" -o command= 2>/dev/null)
        cwd=$(lsof -p "$pid" -a -d cwd -F n 2>/dev/null | grep '^n' | cut -c2- | head -n1)

        all_data+=("$pid|$threads|$fds|$cmd|$cwd")
    done

    # Calculate column widths
    local pid_width=3 threads_width=7 fds_width=3 cmd_width=7

    for data in "${all_data[@]}"; do
        IFS='|' read -r pid threads fds cmd _ <<< "$data"
        [[ ${#pid} -gt $pid_width ]] && pid_width=${#pid}
        [[ ${#threads} -gt $threads_width ]] && threads_width=${#threads}
        [[ ${#fds} -gt $fds_width ]] && fds_width=${#fds}
        [[ ${#cmd} -gt $cmd_width ]] && cmd_width=${#cmd}
    done

    # Print table header
    printf "%-$((pid_width + 3))s%-$((threads_width + 3))s%-$((fds_width + 3))s%-$((cmd_width + 3))s%s\n" \
        "PID" "Threads" "FDs" "Command" "CWD"

    # Print data rows
    for data in "${all_data[@]}"; do
        IFS='|' read -r pid threads fds cmd cwd <<< "$data"
        printf "%-$((pid_width + 3))s%-$((threads_width + 3))s%-$((fds_width + 3))s%-$((cmd_width + 3))s%s\n" \
            "$pid" "$threads" "$fds" "$cmd" "$cwd"
    done
}
