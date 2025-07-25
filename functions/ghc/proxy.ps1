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


