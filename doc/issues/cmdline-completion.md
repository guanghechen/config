## Issue Details

The position of the popup of the cmdline completion provided by the blink.cmp is incorrect, since I have my customized ui_attach on @lua/fml/dressing/ui_attach, so the cmdline position actually on the top-center, but the popup of the cmdline completion is on the bottom-left, which make things weird. 


## Expected Fix

I wish the popup can showing under the cmdline exactly instead of the bottom-left.

### System Info

- **OS**: wsl + ubuntu 24.04.3 LTS
- **terminal**: Windows Terminal + tmux next-3.6
- **shell**: fish 4.1.0
- **neovim**: 0.11.4

