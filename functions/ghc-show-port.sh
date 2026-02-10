# shellcheck shell=bash
# ghc-show-port - Show processes listening on a specific port

ghc-show-port() {
    if [[ $# -eq 0 ]]; then
        printf "\e[93m  Usage: ghc-show-port <port>\e[0m\n"
        return 1
    fi

    local port="$1"

    # Validate port number
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        printf "\e[91m  Error: Port must be a number\e[0m\n"
        return 1
    fi

    # Collect all data first
    local -a all_data=()

    # Use lsof to find processes listening on the port
    local lsof_output
    lsof_output=$(lsof -i :"$port" -n -P 2>/dev/null)

    local line_count
    line_count=$(echo "$lsof_output" | wc -l | tr -d ' ')

    if [[ $line_count -le 1 ]]; then
        printf "\e[93m  No processes found listening on port %s\e[0m\n" "$port"
        return 0
    fi

    # Skip the header line and process each line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Parse lsof output
        read -r command pid user fd type device size node name <<< "$line"

        # Get additional process info
        local cpu_mem cmd_full cwd
        cpu_mem=$(ps -p "$pid" -o %cpu,%mem 2>/dev/null | tail -n 1 | tr -s ' ' | sed 's/^ //;s/ /,/')
        cmd_full=$(ps -p "$pid" -o command= 2>/dev/null | sed 's/^ *//')
        cwd=$(lsof -p "$pid" -a -d cwd -F n 2>/dev/null | grep '^n' | cut -c2- | head -n1)

        # Handle empty values
        [[ -z "$cpu_mem" ]] && cpu_mem="N/A"
        [[ -z "$cmd_full" ]] && cmd_full="N/A"
        [[ -z "$cwd" ]] && cwd="N/A"

        all_data+=("$command|$pid|$user|$name|$cpu_mem|$cmd_full|$cwd")
    done <<< "$(echo "$lsof_output" | tail -n +2)"

    # Calculate column widths
    local command_width=7 pid_width=3 user_width=4 name_width=7 cpu_mem_width=8

    for data in "${all_data[@]}"; do
        IFS='|' read -r cmd pid user name cpu_mem _ _ <<< "$data"
        [[ ${#cmd} -gt $command_width ]] && command_width=${#cmd}
        [[ ${#pid} -gt $pid_width ]] && pid_width=${#pid}
        [[ ${#user} -gt $user_width ]] && user_width=${#user}
        [[ ${#name} -gt $name_width ]] && name_width=${#name}
        [[ ${#cpu_mem} -gt $cpu_mem_width ]] && cpu_mem_width=${#cpu_mem}
    done

    # Print table header
    printf "%-$((command_width + 3))s%-$((pid_width + 3))s%-$((user_width + 3))s%-$((name_width + 3))s%-$((cpu_mem_width + 3))s%-30s%s\n" \
        "Command" "PID" "User" "Address" "CPU,MEM" "Full Command" "CWD"

    # Print data rows
    for data in "${all_data[@]}"; do
        IFS='|' read -r cmd pid user name cpu_mem cmd_full cwd <<< "$data"
        # Truncate long command
        local cmd_display="$cmd_full"
        if [[ ${#cmd_display} -gt 30 ]]; then
            cmd_display="${cmd_display:0:27}..."
        fi
        printf "%-$((command_width + 3))s%-$((pid_width + 3))s%-$((user_width + 3))s%-$((name_width + 3))s%-$((cpu_mem_width + 3))s%-30s%s\n" \
            "$cmd" "$pid" "$user" "$name" "$cpu_mem" "$cmd_display" "$cwd"
    done
}
