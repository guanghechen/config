local actions = require("ark.vendor.vscode.action")

local mk = stl.nvim.fn.make_keys

---@param modes                         string[]
---@param keys                          string|string[]
---@param action                        string
---@param desc                          ?string
---@return nil
local function mvs(modes, keys, action, desc)
  mk(modes, keys, "<cmd>lua require('vscode').action('" .. action .. "')<cr>", desc)
end

--#enhance------------------------------------------------------------------------------------------
----- better navigation-----
mk({ "n" }, "[i", actions.goto_indent_scope_top, "goto: indent scope top")
mk({ "n" }, "]i", actions.goto_indent_scope_bot, "goto: indent scope bottom")
------------------------------------------------------------------------------------------#enhance--

-- Keep undo/redo lists in sync with VsCode
mk({ "n" }, "u", "<Cmd>call VSCodeNotify('undo')<CR>")
mk({ "n" }, "<C-r>", "<Cmd>call VSCodeNotify('redo')<CR>")

--#[b]uf--------------------------------------------------------------------------------------------
mvs({ "n", "x" }, { "<leader>[", "<leader>b[" }, "workbench.action.previousEditorInGroup", "buf: prev")
mvs({ "n", "x" }, { "<leader>]", "<leader>b]" }, "workbench.action.nextEditorInGroup", "buf: next")
mvs({ "n", "x" }, { "<leader>{", "<leader>b{" }, "workbench.action.moveEditorLeftInGroup", "buf: move left")
mvs({ "n", "x" }, { "<leader>}", "<leader>b}" }, "workbench.action.moveEditorRightInGroup", "buf: move right")
mvs({ "n", "x" }, "<leader>bH", "workbench.action.moveEditorToLeftGroup", "buf: move to left group")
mvs({ "n", "x" }, "<leader>bJ", "workbench.action.moveEditorToBottomGroup", "buf: move to bottom group")
mvs({ "n", "x" }, "<leader>bK", "workbench.action.moveEditorToAboveGroup", "buf: move to above group")
mvs({ "n", "x" }, "<leader>bL", "workbench.action.moveEditorToRightGroup", "buf: move to right group")
mvs({ "n", "x" }, "<leader>bd", "workbench.action.closeActiveEditor", "buf: close")
mvs({ "n", "x" }, "<leader>bh", "workbench.action.closeEditorsToTheLeft", "buf: close to left")
mvs({ "n", "x" }, "<leader>bl", "workbench.action.closeEditorsToTheRight", "buf: close to right")
mvs({ "n", "x" }, "<leader>bo", "workbench.action.closeOtherEditors", "buf: close others")
mvs({ "n", "x" }, "<leader>bn", "workbench.action.files.newUntitledFile", "buf: new")
mvs({ "i", "n", "x" }, { "<C-a>s", "<D-s>", "<M-s>" }, "workbench.action.files.save", "buf: save")
--------------------------------------------------------------------------------------------#[b]uf--

--#[c]ode-------------------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>ca", "editor.action.quickFix", "code: quick fix")
mvs({ "n", "x" }, "<leader>cf", "editor.action.formatDocument", "code: format")
mvs({ "n", "x" }, "<leader>cr", "editor.action.rename", "code: rename")
mvs({ "n", "x" }, "<leader>co", "editor.action.organizeImports", "code: organize imports")
mvs({ "n", "x" }, "gQ", "editor.action.formatDocument", "code: format")
-------------------------------------------------------------------------------------------#[c]ode--

--#[c]opy-------------------------------------------------------------------------------------------
mvs({ "i", "n", "x" }, { "<C-a>C", "<D-C>", "<M-C>" }, "workbench.action.files.copyPathOfActiveFile", "copy: file path")
mvs({ "n", "x" }, "<leader>yp", "workbench.action.files.copyPathOfActiveFile", "copy: file path")
mvs({ "n", "x" }, "<leader>yr", "copyRelativeFilePath", "copy: relative file path")
-------------------------------------------------------------------------------------------#[c]opy--

--#[f]ind-------------------------------------------------------------------------------------------
mk({ "n" }, "<leader><leader>", "<cmd>Find<cr>", "find: files")
mvs({ "n", "x" }, "<leader>fb", "workbench.action.showAllEditors", "find: buffers")
mvs({ "n", "x" }, "<leader>fc", "workbench.action.showCommands", "find: commands")
mvs({ "n", "x" }, "<leader>ff", "workbench.action.quickOpen", "find: files")
mvs({ "n", "x" }, "<leader>fg", "workbench.view.scm", "find: git")
mvs({ "n", "x" }, "<leader>fh", "workbench.action.openGlobalKeybindingsFile", "find: keybindings file")
mvs({ "n", "x" }, "<leader>fs", "workbench.action.gotoSymbol", "find: symbols")
mvs({ "n", "x" }, "<leader>fS", "workbench.action.showAllSymbols", "find: workspace symbols")
mvs({ "n", "x" }, "<leader>fr", "workbench.action.openRecent", "find: recent")
mvs({ "n", "x" }, { "<leader>f?", "<leader>?" }, "workbench.action.openGlobalKeybindings", "find: keymaps")
-------------------------------------------------------------------------------------------#[f]ind--

--#[g]it--------------------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>gg", "workbench.view.scm", "git: open scm")
mvs({ "n", "x" }, "<leader>gb", "gitlens.toggleFileBlame", "git: toggle blame (GitLens)")
mvs({ "n", "x" }, "<leader>gB", "gitlens.openFileOnRemote", "git: open on remote (GitLens)")
mvs({ "n", "x" }, "<leader>gd", "git.openChange", "git: diff")
mvs({ "n", "x" }, "<leader>gD", "gitlens.showQuickFileHistory", "git: file history (GitLens)")
mvs({ "n", "x" }, "ghs", "git.stageSelectedRanges", "git: stage hunk")
mvs({ "n", "x" }, "ghu", "git.unstageSelectedRanges", "git: unstage hunk")
mvs({ "n", "x" }, "ghr", "git.revertSelectedRanges", "git: revert hunk")
mvs({ "n", "x" }, "ghS", "git.stage", "git: stage file")
mvs({ "n", "x" }, "ghR", "git.clean", "git: discard file changes")
mvs({ "n", "x" }, "[h", "workbench.action.editor.previousChange", "git: prev hunk")
mvs({ "n", "x" }, "]h", "workbench.action.editor.nextChange", "git: next hunk")
--------------------------------------------------------------------------------------------#[g]it--

--#[l]sp--------------------------------------------------------------------------------------------
mvs({ "n" }, "gd", "editor.action.revealDefinition", "lsp: go to definition")
mvs({ "n" }, "gD", "editor.action.revealDeclaration", "lsp: go to declaration")
mvs({ "n" }, "gr", "editor.action.goToReferences", "lsp: go to references")
mvs({ "n" }, "gI", "editor.action.goToImplementation", "lsp: go to implementation")
mvs({ "n" }, "gy", "editor.action.goToTypeDefinition", "lsp: go to type definition")
mvs({ "n" }, "K", "editor.action.showHover", "lsp: hover")
mvs({ "n" }, "<leader>lh", "editor.action.showHover", "lsp: hover")
mvs({ "n" }, "<leader>ls", "editor.action.triggerParameterHints", "lsp: signature help")
--------------------------------------------------------------------------------------------#[l]sp--

--#[s]earch-----------------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>ss", "workbench.action.findInFiles", "search: in files")
mvs({ "n", "x" }, "<leader>sb", "actions.find", "search: in buffer")
mvs({ "n", "x" }, "<leader>sr", "workbench.action.replaceInFiles", "search: replace in files")
mvs({ "i", "n", "x" }, { "<C-a>f", "<D-f>", "<M-f>" }, "actions.find", "search: in buffer")
-----------------------------------------------------------------------------------------#[s]earch--

--#[t]ab--------------------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>,", "workbench.action.previousEditor", "tab: prev")
mvs({ "n", "x" }, "<leader>.", "workbench.action.nextEditor", "tab: next")
mvs({ "n", "x" }, "<leader>td", "workbench.action.closeActiveEditor", "tab: close")
mvs({ "n", "x" }, "<leader>to", "workbench.action.closeOtherEditors", "tab: close others")
mvs({ "n", "x" }, "<leader>tH", "workbench.action.closeEditorsToTheLeft", "tab: close to left")
mvs({ "n", "x" }, "<leader>tL", "workbench.action.closeEditorsToTheRight", "tab: close to right")
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]erminal---------------------------------------------------------------------------------------
mvs({ "i", "n", "t", "x" }, { "<C-a>t", "<D-t>", "<M-t>" }, "workbench.action.terminal.toggleTerminal", "term: toggle")
mvs({ "n", "x" }, "<leader>tt", "workbench.action.terminal.toggleTerminal", "term: toggle")
mvs({ "n", "x" }, "<leader>tn", "workbench.action.terminal.new", "term: new")
---------------------------------------------------------------------------------------#[t]erminal--

--#[u]i/toggle--------------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>ue", "workbench.action.toggleSidebarVisibility", "ui: toggle sidebar")
mvs({ "n", "x" }, "<leader>up", "workbench.action.togglePanel", "ui: toggle panel")
mvs({ "n", "x" }, "<leader>uz", "workbench.action.toggleZenMode", "ui: toggle zen mode")
mvs({ "n", "x" }, "<leader>uZ", "workbench.action.toggleMaximizedPanel", "ui: toggle maximized panel")
mvs({ "n", "x" }, "<leader>um", "workbench.action.toggleMinimap", "ui: toggle minimap")
mvs({ "n", "x" }, "<leader>uw", "editor.action.toggleWordWrap", "ui: toggle word wrap")
mvs({ "i", "n", "x" }, { "<C-a>T", "<D-T>", "<M-T>" }, "workbench.action.selectTheme", "ui: select theme")
--------------------------------------------------------------------------------------#[u]i/toggle--

--#[w]in--------------------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>wd", "workbench.action.closeActiveEditor", "win: close")
mvs({ "n", "x" }, "<leader>wh", "workbench.action.splitEditorLeft", "win: split left")
mvs({ "n", "x" }, "<leader>wj", "workbench.action.splitEditorDown", "win: split down")
mvs({ "n", "x" }, "<leader>wk", "workbench.action.splitEditorUp", "win: split up")
mvs({ "n", "x" }, "<leader>wl", "workbench.action.splitEditorRight", "win: split right")
mvs({ "n", "x" }, "<leader>wo", "workbench.action.closeEditorsInOtherGroups", "win: close others")
mvs({ "n", "x" }, "<leader>ww", "workbench.action.focusNextGroup", "win: focus next group")
mvs({ "n", "x" }, "<leader>wW", "workbench.action.focusPreviousGroup", "win: focus prev group")
mvs({ "i", "n", "t", "x" }, { "<C-a>h", "<D-h>", "<M-h>" }, "workbench.action.focusLeftGroup", "win: focus left")
mvs({ "i", "n", "t", "x" }, { "<C-a>j", "<D-j>", "<M-j>" }, "workbench.action.focusBelowGroup", "win: focus below")
mvs({ "i", "n", "t", "x" }, { "<C-a>k", "<D-k>", "<M-k>" }, "workbench.action.focusAboveGroup", "win: focus above")
mvs({ "i", "n", "t", "x" }, { "<C-a>l", "<D-l>", "<M-l>" }, "workbench.action.focusRightGroup", "win: focus right")
mvs({ "n", "x" }, "z;", "workbench.action.toggleEditorWidths", "win: toggle maximize")
--------------------------------------------------------------------------------------------#[w]in--

--#[x] diagnostic-----------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>xd", "workbench.actions.view.problems", "diagnostic: problems")
mvs({ "n", "x" }, "[d", "editor.action.marker.prev", "diagnostic: prev")
mvs({ "n", "x" }, "]d", "editor.action.marker.next", "diagnostic: next")
mvs({ "n", "x" }, "[e", "editor.action.marker.prevInFiles", "diagnostic: prev error")
mvs({ "n", "x" }, "]e", "editor.action.marker.nextInFiles", "diagnostic: next error")
-----------------------------------------------------------------------------------#[x] diagnostic--

--#[z] fold---------------------------------------------------------------------------------------
mvs({ "n", "x" }, "za", "editor.toggleFold", "fold: toggle")
mvs({ "n", "x" }, "zo", "editor.unfold", "fold: open")
mvs({ "n", "x" }, "zc", "editor.fold", "fold: close")
mvs({ "n", "x" }, "zO", "editor.unfoldRecursively", "fold: open recursively")
mvs({ "n", "x" }, "zC", "editor.foldRecursively", "fold: close recursively")
mvs({ "n", "x" }, "zR", "editor.unfoldAll", "fold: open all")
mvs({ "n", "x" }, "zM", "editor.foldAll", "fold: close all")
mvs({ "n", "x" }, "[z", "editor.gotoParentFold", "fold: go to parent")
---------------------------------------------------------------------------------------#[z] fold--

--#[1] sidebar--------------------------------------------------------------------------------------
mvs({ "n", "x" }, { "<C-a>1", "<D-1>", "<M-1>" }, "workbench.view.explorer", "sidebar: explorer")
mvs({ "n", "x" }, { "<C-a>2", "<D-2>", "<M-2>" }, "workbench.view.search", "sidebar: search")
mvs({ "n", "x" }, { "<C-a>3", "<D-3>", "<M-3>" }, "workbench.view.scm", "sidebar: git")
mvs({ "n", "x" }, { "<C-a>4", "<D-4>", "<M-4>" }, "workbench.view.debug", "sidebar: debug")
mvs({ "n", "x" }, { "<C-a>5", "<D-5>", "<M-5>" }, "workbench.view.extensions", "sidebar: extensions")
--------------------------------------------------------------------------------------#[1] sidebar--

--#[e]xplorer---------------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>1", "workbench.view.explorer", "explorer: focus")
mvs({ "n", "x" }, "<leader>er", "workbench.files.action.showActiveFileInExplorer", "explorer: reveal file")
mvs({ "n", "x" }, "<leader>et", "workbench.action.toggleSidebarVisibility", "explorer: toggle")
---------------------------------------------------------------------------------------#[e]xplorer--
