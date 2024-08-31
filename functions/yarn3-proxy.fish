function yarn3-proxy
  if test "$argv[1]" = "on"
    yarn config set httpProxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
    yarn config set httpsProxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
  else if test "$argv[1]" = "off"
    yarn config unset httpProxy
    yarn config unset httpsProxy
  else
    set config_value (yarn config get httpProxy)
    if test -z "$config_value"
      yarn config set httpProxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
      yarn config set httpsProxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
    else
      yarn config unset httpProxy
      yarn config unset httpsProxy
    end
  end
end
