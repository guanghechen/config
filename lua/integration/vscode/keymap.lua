local fn = require("eve.builtin.fn")
local actions = require("integration.vscode.action")

local mk = fn.make_keys

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
mvs({ "n", "v" }, { "<leader>[", "<leader>b[" }, "workbench.action.previousEditorInGroup")
mvs({ "n", "v" }, { "<leader>]", "<leader>b]" }, "workbench.action.nextEditorInGroup")
mvs({ "n", "v" }, { "<leader>{", "<leader>b{" }, "workbench.action.moveEditorLeftInGroup")
mvs({ "n", "v" }, { "<leader>}", "<leader>b}" }, "workbench.action.moveEditorRightInGroup")
mvs({ "n", "v" }, "<leader>bH", "workbench.action.moveEditorToLeftGroup")
mvs({ "n", "v" }, "<leader>bJ", "workbench.action.moveEditorToBottomGroup")
mvs({ "n", "v" }, "<leader>bK", "workbench.action.moveEditorToAboveGroup")
mvs({ "n", "v" }, "<leader>bL", "workbench.action.moveEditorToRightGroup")
mvs({ "n", "v" }, "<leader>bd", "workbench.action.closeActiveEditor")
mvs({ "n", "v" }, "<leader>bh", "workbench.action.closeEditorsToTheLeft")
mvs({ "n", "v" }, "<leader>bl", "workbench.action.closeEditorsToTheRight")
mvs({ "n", "v" }, "<leader>bo", "workbench.action.closeOtherEditors")
--------------------------------------------------------------------------------------------#[b]uf--

--#[c]ode-------------------------------------------------------------------------------------------
mvs({ "n", "v" }, "<leader>cr", "editor.action.rename")
-------------------------------------------------------------------------------------------#[c]ode--

--#[f]ind-------------------------------------------------------------------------------------------
mk({ "n" }, "<leader><leader>", "<cmd>Find<cr>")
-------------------------------------------------------------------------------------------#[f]ind--

--#[s]earch-----------------------------------------------------------------------------------------
mvs({ "n" }, "<leader>ss", "workbench.action.findInFiles")
-----------------------------------------------------------------------------------------#[s]earch--

--#[w]in--------------------------------------------------------------------------------------------
mvs({ "n", "v" }, "<leader>wh", "workbench.action.splitEditorLeft")
mvs({ "n", "v" }, "<leader>wj", "workbench.action.splitEditorDown")
mvs({ "n", "v" }, "<leader>wk", "workbench.action.splitEditorUp")
mvs({ "n", "v" }, "<leader>wl", "workbench.action.splitEditorRight")
--------------------------------------------------------------------------------------------#[w]in--
