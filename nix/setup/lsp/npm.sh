#! /usr/bin/env bash

## @see https://mason-registry.dev/registry/list
source $HOME/.config/guanghechen/nix/setup/path.sh

npm i -g bash-language-server                # [lsp] bash:                   https://github.com/bash-lsp/bash-language-server
npm i -g vscode-langservers-extracted        # [lsp] css/eslint/html/json:   https://github.com/hrsh7th/vscode-langservers-extracted
npm i -g @microsoft/compose-language-service # [lsp] docker:                 https://github.com/microsoft/compose-language-service
npm i -g dockerfile-language-server-nodejs   # [lsp] docker:                 https://github.com/rcjsuen/dockerfile-language-server
npm i -g pyright                             # [lsp] python:                 https://github.com/microsoft/pyright
npm i -g @tailwindcss/language-server        # [lsp] tailwind:               https://github.com/tailwindlabs/tailwindcss-intellisense/tree/HEAD/packages/tailwindcss-language-server
npm i -g @vtsls/language-server              # [lsp] typescript:             https://github.com/yioneko/vtsls
npm i -g vls                                 # [lsp] vue:                    https://github.com/vuejs/vetur/tree/master/server
npm i -g yaml-language-server                # [lsp] yaml:                   https://github.com/redhat-developer/yaml-language-server
npm i -g cspell                              # [lint] spellcheck:            https://github.com/streetsidesoftware/cspell/tree/main/packages/cspell
npm i -g prettier                            # [prettier] css/js/ts/html/json https://github.com/prettier/prettier
