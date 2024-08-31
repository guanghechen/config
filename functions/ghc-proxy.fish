function ghc-proxy
  if test "$argv[1]" = "on"
    set -gx http_proxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
    set -gx https_proxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
  else if test "$argv[1]" = "off"
    set -e http_proxy
    set -e https_proxy
  else
    if test -z "$http_proxy"
      set -gx http_proxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
      set -gx https_proxy "http://$ghc_vpn_host_ip:$ghc_vpn_host_port"
    else
      set -e http_proxy
      set -e https_proxy
    end
  end
end
