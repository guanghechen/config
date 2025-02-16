local fn = require("eve.builtin.fn")
local mk = fn.make_keys

---@param modes                         string[]
---@param keys                          string|string[]
---@param action                        string
---@return nil
local function mvs(modes, keys, action)
  mk(modes, keys, [[<cmd>lua require('vscode').action('workbench.action.]] .. action .. [[')<cr>]])
end

-- Keep undo/redo lists in sync with VsCode
mk({ "n" }, "u", "<Cmd>call VSCodeNotify('undo')<CR>")
mk({ "n" }, "<C-r>", "<Cmd>call VSCodeNotify('redo')<CR>")

--#[b]uf--------------------------------------------------------------------------------------------
mvs({ "n", "v" }, { "<leader>[", "<leader>b[" }, "previousEditorInGroup")
mvs({ "n", "v" }, { "<leader>]", "<leader>b]" }, "nextEditorInGroup")
mvs({ "n", "v" }, { "<leader>{", "<leader>b{" }, "moveEditorLeftInGroup")
mvs({ "n", "v" }, { "<leader>}", "<leader>b}" }, "moveEditorRightInGroup")
mvs({ "n", "v" }, "<leader>bH", "moveEditorToLeftGroup")
mvs({ "n", "v" }, "<leader>bJ", "moveEditorToBottomGroup")
mvs({ "n", "v" }, "<leader>bK", "moveEditorToAboveGroup")
mvs({ "n", "v" }, "<leader>bL", "moveEditorToRightGroup")
mvs({ "n", "v" }, "<leader>bd", "closeActiveEditor")
mvs({ "n", "v" }, "<leader>bh", "closeEditorsToTheLeft")
mvs({ "n", "v" }, "<leader>bl", "closeEditorsToTheRight")
mvs({ "n", "v" }, "<leader>bo", "closeOtherEditors")
--------------------------------------------------------------------------------------------#[b]uf--

--#[f]ind-------------------------------------------------------------------------------------------
mk({ "n" }, "<leader><leader>", "<cmd>Find<cr>")
-------------------------------------------------------------------------------------------#[f]ind--

--#[s]earch-----------------------------------------------------------------------------------------
mvs({ "n" }, "<leader>ss", "findInFiles")
-----------------------------------------------------------------------------------------#[s]earch--
