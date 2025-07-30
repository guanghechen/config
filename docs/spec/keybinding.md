## Keybinding Specification

1. [x] Bind `<ctrl>+;` to launch the file explorer.
2. [x] The keybinding should care the platform: osx|win|nix|all

## Requirements

1. Handle all keybindings on the isolate top layer, let's place all keybindings codes into
   src/keybindings/ folder.
2. We can register a customized keybinding on the keybinding layer and get callback to handle the
   keybinding.
