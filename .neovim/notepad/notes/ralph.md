----------------------------------------------------------------------------------------------------

/ralph-loop:ralph-loop "深入分析我们的改动是否存在什么问题，修复所有你发现的简单问题，对于复杂问题先列出来等待修复，这是一个长期的过程，请保持耐心、谨慎。" --completion-promise "NO MORE ACTION CAN BE TAKEN!" --max-iterations 8


----------------------------------------------------------------------------------------------------

__TMUX_PANE_ID__=55

/ralph-loop:ralph-loop "请修复所有的 lsp diagnostic issues，你需要仔细阅读 @spec/debug/lsp.md 中的引导去理解如何获取 lsp 信息。你可以使用 tmux pane %${__TMUX_PANE_ID__} 来做这件事。直到没有任何需要修复的 diagnostics 诊断信息。" --completion-promise "NO MORE ACTION CAN BE TAKEN!" --max-iterations 8


----------------------------------------------------------------------------------------------------

__TMUX_PANE_ID__=55

/ralph-loop:ralph-loop "阅读 tmux pane %${__TMUX_PANE_ID__} 中 codex 的分析，然后修复合理的问题或者发送消息给 codex (tmux pane %${__TMUX_PANE_ID__}) 和其讨论，等待它的回复，直到你们达成共识，或者需要我的介入。" --completion-promise "NO MORE ACTION CAN BE TAKEN!" --max-iterations 8

----------------------------------------------------------------------------------------------------

/ralph-loop:ralph-loop "深入分析我们的改动是否存在什么问题，修复所有你发现的简单问题，对于复杂问题先列出来等待修复，这是一个长期的过程，请保持耐心、谨慎。" --completion-promise "NO MORE ACTION CAN BE TAKEN!" --max-iterations 8

----------------------------------------------------------------------------------------------------

/ralph-loop:ralph-loop "根据我们的规范深入、全面的更新我们的所有代码使其符合规范，请注意，我们永远只需要考虑最新的API，因此无需考虑兼容性。" --completion-promise "NO MORE ACTION CAN BE TAKEN!" --max-iterations 8

----------------------------------------------------------------------------------------------------

/ralph-loop:ralph-loop "仔细 review 一下我们的重构是否改变了原先的执行逻辑，或是引入了新的问题，若是有，修复它们" --completion-promise "NO MORE ACTION CAN BE TAKEN!" --max-iterations 8

----------------------------------------------------------------------------------------------------

