local actions = require("ark.vendor.vscode.action")

local mk = stl.nvim.fn.make_keys

---@param modes                         string[]
---@param keys                          string|string[]
---@param action                        string
---@return nil
local function mvs(modes, keys, action)
  mk(modes, keys, "<cmd>lua require('vscode').action('" .. action .. "')<cr>")
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
mvs({ "n", "x" }, { "<leader>[", "<leader>b[" }, "workbench.action.previousEditorInGroup")
mvs({ "n", "x" }, { "<leader>]", "<leader>b]" }, "workbench.action.nextEditorInGroup")
mvs({ "n", "x" }, { "<leader>{", "<leader>b{" }, "workbench.action.moveEditorLeftInGroup")
mvs({ "n", "x" }, { "<leader>}", "<leader>b}" }, "workbench.action.moveEditorRightInGroup")
mvs({ "n", "x" }, "<leader>bH", "workbench.action.moveEditorToLeftGroup")
mvs({ "n", "x" }, "<leader>bJ", "workbench.action.moveEditorToBottomGroup")
mvs({ "n", "x" }, "<leader>bK", "workbench.action.moveEditorToAboveGroup")
mvs({ "n", "x" }, "<leader>bL", "workbench.action.moveEditorToRightGroup")
mvs({ "n", "x" }, "<leader>bd", "workbench.action.closeActiveEditor")
mvs({ "n", "x" }, "<leader>bh", "workbench.action.closeEditorsToTheLeft")
mvs({ "n", "x" }, "<leader>bl", "workbench.action.closeEditorsToTheRight")
mvs({ "n", "x" }, "<leader>bo", "workbench.action.closeOtherEditors")
--------------------------------------------------------------------------------------------#[b]uf--

--#[c]ode-------------------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>cr", "editor.action.rename")
-------------------------------------------------------------------------------------------#[c]ode--

--#[f]ind-------------------------------------------------------------------------------------------
mk({ "n" }, "<leader><leader>", "<cmd>Find<cr>")
-------------------------------------------------------------------------------------------#[f]ind--

--#[s]earch-----------------------------------------------------------------------------------------
mvs({ "n" }, "<leader>ss", "workbench.action.findInFiles")
-----------------------------------------------------------------------------------------#[s]earch--

--#[w]in--------------------------------------------------------------------------------------------
mvs({ "n", "x" }, "<leader>wd", "workbench.action.closeActiveEditor")
mvs({ "n", "x" }, "<leader>wh", "workbench.action.splitEditorLeft")
mvs({ "n", "x" }, "<leader>wj", "workbench.action.splitEditorDown")
mvs({ "n", "x" }, "<leader>wk", "workbench.action.splitEditorUp")
mvs({ "n", "x" }, "<leader>wl", "workbench.action.splitEditorRight")
mvs({ "n", "x" }, "<leader>wo", "workbench.action.closeEditorsInOtherGroups")
mvs({ "n", "x" }, "<leader>ww", "workbench.action.focusNextGroup")
--------------------------------------------------------------------------------------------#[w]in--
