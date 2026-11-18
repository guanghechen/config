---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.picker.keymap" ---@type string

local M = {}

---Normal-mode motions a read-only pane takes in Insert mode, unless one of its keys takes the same key.
local MOTIONS = { "j", "k", "gg", "G", "<C-d>", "<C-u>" } ---@type string[]

---Binds the keys of a read-only pane. Insert mode reaches the pane only with a focus move, from the finder for
---instance, and the pane takes the keys there as it does in Normal mode: the keys bound in Normal mode are bound in
---Insert mode too, and the motions above move the cursor. A key sequence stays in the modes it was written for.
---@param keymaps                       stl.t.IKeymap[]
---@param bufnr                         integer
---@return nil
function M.bind(keymaps, bufnr)
  local resolved = {} ---@type stl.t.IKeymap[]
  for _, key in ipairs(MOTIONS) do
    local keys = vim.keycode(key) ---@type string
    resolved[#resolved + 1] = {
      modes = { "i" },
      key = key,
      desc = "picker: Normal-mode " .. key,
      callback = function()
        vim.cmd.normal({ args = { keys }, bang = true })
      end,
    }
  end
  for _, keymap in ipairs(keymaps) do
    local modes = keymap.modes ---@type stl.t.VimModeEnum[]
    if type(keymap.callback) == "function" and vim.list_contains(modes, "n") and not vim.list_contains(modes, "i") then
      keymap = vim.tbl_extend("force", keymap, { modes = vim.list_extend({ "i" }, modes) })
    end
    resolved[#resolved + 1] = keymap
  end
  stl.nvim.fn.bindkeys(resolved, { bufnr = bufnr, nowait = true, noremap = true, silent = true })
end

return M
