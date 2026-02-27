@lsp/ 逐一更新我们的 lspconfig，需要和 [nvim-lspconfig][] 中的对齐

1. 你可以注意到，@lsp/ 下的每个 lsp 配置文件的顶部链接中其实都包含了一个 commit hash，它是我们上次跟进的版本的 commit hash，因此你需要在 [nvim-lspconfig][] 中找到那个 commit hash 到当前最新 commit (HEAD) 之间这个文件的差异，然后分析哪些是可用的
2. 在更新我们的 config 的过程中，尽量宁缺毋滥，你需要深刻分析是否值得或者 [nvim-lspconfig][] 和我们本地相比哪个更优，择优而录。
3. 我们只需要考虑最新版本的 neovim，因此那些出于 compatibility 因素的代码我们可以简单化处理，无需 conditionals
4. 如果你有任何拿捏不准或者无法确认的问题和困惑，请及时抛出来和我讨论呢。
5. 当你完成了一个 lsp 配置的更新后，你需要把顶部的 hash 改成其最后一次更新后的 hash （请注意是这个文件对应的配置文件最后一次更新的 hash，而不是 HEAD commit hash!)

[]: ~/sourcecodes/github/neovim/nvim-lspconfig

