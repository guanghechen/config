function ghc-proxy {
  param (
    [string]$action
  )

  # $env:ghc_vpn_host_ip = ipconfig | Select-String "IPv4 Address" | ForEach-Object { $_.Line.Split(":")[1].Trim() } | Where-Object { $_ -like "192*" } | Select-Object -First 1
  $env:ghc_vpn_host_ip = '127.0.0.1'
  setx ghc_vpn_host_ip "$env:ghc_vpn_host_ip"

  $proxy = "http://$env:ghc_vpn_host_ip`:$env:ghc_vpn_host_port"

  if ($action -eq "on") {
    [System.Environment]::SetEnvironmentVariable("HTTP_PROXY", $proxy, [System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", $proxy, [System.EnvironmentVariableTarget]::User)

    git config --global http.proxy $proxy
    git config --global https.proxy $proxy

    npm config set proxy $proxy
    npm config set https-proxy $proxy

    Write-Output "Proxy enabled: $proxy"

  } elseif ($action -eq "off") {
    [System.Environment]::SetEnvironmentVariable("HTTP_PROXY", $null, [System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", $null, [System.EnvironmentVariableTarget]::User)

    git config --global --unset http.proxy
    git config --global --unset https.proxy

    npm config delete proxy
    npm config delete https-proxy

    Write-Output "Proxy disabled."

  } else {
    $currentHttpProxy = [System.Environment]::GetEnvironmentVariable("HTTP_PROXY", [System.EnvironmentVariableTarget]::User)
    if ($currentHttpProxy) {
      ghc-proxy off
    } else {
      ghc-proxy on
    }
  }
}

# Apply a given theme.
function ghc-theme-apply {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\config\theme\apply_theme.mjs"
  if (Test-Path -Path $script_path) {
    $first_arg = if ($args -and $args.Count -gt 0) {
      $args[0].ToString().Trim() -replace '^\s+|\s+$', '' -replace '([A-Z])', { $_.Value.ToLower() }
    } else {
      ""
    }
    node $script_path $first_arg
  } else {
    Write-Host "Cannot find the script file: $script_path." -foregroundcolor Red
  }
}

# Toggle theme.
function ghc-theme-toggle {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\config\theme\toggle_theme.mjs"
  if (Test-Path -Path $script_path) {
    $first_arg = if ($args -and $args.Count -gt 0) {
      $args[0].ToString().Trim() -replace '^\s+|\s+$', '' -replace '([A-Z])', { $_.Value.ToLower() }
    } else {
      ""
    }
    node $script_path $first_arg
  } else {
    Write-Host "Cannot find the script file: $script_path." -foregroundcolor Red
  }
}

# Generate themes.
function ghc-theme-gen {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\config\theme\gen_themes.mjs"
  if (Test-Path -Path $script_path) {
    node "$script_path"
  } else {
    Write-Host "Cannot find the script file: $script_path." -foregroundcolor Red
  }
}

# Upgrade dev env.
function ghc-upgrade {
  pwsh "$env:XDG_CONFIG_HOME\guanghechen\win\setup.ps1"
}

# Update config repositories.
function ghc-update {
  $required_configs = @(
    "conda",
    "fzf",
    'guanghechen',
    "lazygit",
    "nvim",
    "pwsh",
    "ripgrep",
    "yazi"
  )
  $optional_configs = @(
    "alacritty",
    "alacritty-windows",
    "btop",
    "claude",
    "fish",
    "ghostty",
    "helix",
    "kitty",
    "lsd",
    "neovide",
    "nvim-nvchad",
    "opencode",
    "plan",
    "pm2",
    "tsuki",
    "wezterm",
    "yozora"
  )

  foreach ($branch in $required_configs) {
    $repopath = Join-Path $env:XDG_CONFIG_HOME $branch
    if (Test-Path -Path $repopath) {
      Write-Host "fetching $branch into $repopath" -ForegroundColor DarkBlue
      $cmd = "git -C '$repopath' pull origin $branch"
    } else {
      Write-Host "cloning $branch into $repopath" -ForegroundColor DarkBlue
      $cmd = "git clone https://github.com/guanghechen/config.git --single-branch --branch=$branch '$repopath'"
    }
    Invoke-Expression $cmd
    Write-Host
  }

  foreach ($branch in $optional_configs) {
    $repopath = Join-Path $env:XDG_CONFIG_HOME $branch
    if (Test-Path -Path $repopath) {
      Write-Host "fetching $branch into $repopath" -ForegroundColor DarkBlue
      $cmd = "git -C '$repopath' pull origin $branch"
      Invoke-Expression $cmd
      Write-Host
    }
  }
}

