function ghc-proxy-npm
  if test "$argv[1]" = "on"
    npm config set proxy        "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
    npm config set https-proxy  "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
  else if test "$argv[1]" = "off"
    npm config delete proxy
    npm config delete https-proxy
  else
    set config_value (npm config get proxy)
    if test -n "$config_value" -a "$config_value" != "null"
      npm config delete proxy
      npm config delete https-proxy
    else
      npm config set proxy        "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
      npm config set https-proxy  "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
    end
  end
end
