## Variables
set -gx ghc_vpn_host_ip '127.0.0.1'

## Aliases
alias chmod='chmod --preserve-root' # the `--preserve-root` option not worked in MacOS.

## Setup vpn
if test -e /etc/resolv.conf
    set -gx ghc_vpn_host_ip (cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | grep -v '::' | head -1)
else
    set -gx ghc_vpn_host_ip '127.0.0.1'
end
