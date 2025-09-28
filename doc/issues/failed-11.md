## Issue Details

I frequently encounter the `failed 11: resource is not available` error while editing text through neovim. It's occurred even when I editing a small text file or typing on the cmdline, and the error message just suddenly showing aside of the cursor position, which effect me to continuing typing cause the error message overlapped the current characters.

## Expected Fix

1. Analyze the root cause of the `failed 11: resource is not available` error in neovim.

## Minimal Fix

1. At least don't show the error message overlapped the current characters, but show it through the vim.notify instead.


### System Info

- **OS**: wsl + ubuntu 24.04.3 LTS
- **terminal**: Windows Terminal + tmux next-3.6
- **shell**: fish 4.1.0
- **neovim**: 0.11.4
