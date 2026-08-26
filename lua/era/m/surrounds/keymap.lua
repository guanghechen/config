---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.surrounds.keymap" ---@type string

local Action = require("era.m.surrounds.action")
local Buffer = require("era.m.surrounds.buffer")

---@class era.m.surrounds.keymap.IAttached
---@field public mode                   stl.t.VimModeEnum
---@field public key                    string
---@field public identity               string|function

---@class era.m.surrounds.keymap
local M = {}

local attachments = {} ---@type table<integer, era.m.surrounds.keymap.IAttached[]>
local initialized = false ---@type boolean

---@type stl.t.IKeymap[]
local KEYMAPS = {
  { modes = { "n" }, key = "gsa", desc = "surrounds: add", callback = Action.make_operator("add", true), expr = true },
  {
    modes = { "x" },
    key = "gsa",
    desc = "surrounds: add selection",
    callback = ':<C-u>lua era.m.surrounds.add("visual")<CR>',
  },
  {
    modes = { "n" },
    key = "gsd",
    desc = "surrounds: delete",
    callback = Action.make_operator("delete", false),
    expr = true,
  },
  {
    modes = { "n" },
    key = "gsr",
    desc = "surrounds: replace",
    callback = Action.make_operator("replace", false),
    expr = true,
  },
  {
    modes = { "n", "x", "o" },
    key = "gsf",
    desc = "surrounds: find right",
    callback = Action.make_action("find", "right"),
    expr = true,
  },
  {
    modes = { "n", "x", "o" },
    key = "gsF",
    desc = "surrounds: find left",
    callback = Action.make_action("find", "left"),
    expr = true,
  },
  {
    modes = { "n" },
    key = "gsh",
    desc = "surrounds: highlight",
    callback = Action.make_action("highlight", nil),
    expr = true,
  },
}

---@param bufnr                         integer
---@param mode                          stl.t.VimModeEnum
---@param key                           string
---@return table|nil
local function get_keymap(bufnr, mode, key)
  for _, current in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    if current.lhs == key then
      return current
    end
  end
end

---@param keymap                        table
---@return string|function
local function get_keymap_identity(keymap)
  return type(keymap.callback) == "function" and keymap.callback or keymap.rhs
end

---@param bufnr                         integer
---@return nil
local function attach(bufnr)
  stl.nvim.fn.bindkeys(KEYMAPS, { bufnr = bufnr, noremap = true, silent = true })

  local keymaps = {} ---@type era.m.surrounds.keymap.IAttached[]
  for _, keymap in ipairs(KEYMAPS) do
    for _, mode in ipairs(keymap.modes) do
      local current = get_keymap(bufnr, mode, keymap.key) ---@type table|nil
      if current ~= nil then
        keymaps[#keymaps + 1] = {
          mode = mode,
          key = keymap.key,
          identity = get_keymap_identity(current),
        }
      end
    end
  end
  attachments[bufnr] = keymaps
end

---@param bufnr                         integer
---@return nil
local function detach(bufnr)
  for _, attached in ipairs(attachments[bufnr] or {}) do
    local current = get_keymap(bufnr, attached.mode, attached.key) ---@type table|nil
    if current ~= nil and get_keymap_identity(current) == attached.identity then
      pcall(vim.keymap.del, attached.mode, attached.key, { buffer = bufnr })
    end
  end
  attachments[bufnr] = nil
end

---@param bufnr                         integer
---@return nil
function M.refresh(bufnr)
  local available = Buffer.is_available(bufnr) ---@type boolean
  local attached = attachments[bufnr] ~= nil ---@type boolean
  if available and not attached then
    attach(bufnr)
  elseif not available and attached then
    detach(bufnr)
  end
end

---@return nil
function M.setup()
  if initialized then
    return
  end
  initialized = true

  local group = stl.nvim.fn.augroup("era_m_surrounds") ---@type integer
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
    group = group,
    callback = function(event)
      M.refresh(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = { "modifiable", "readonly" },
    callback = function()
      M.refresh(vim.api.nvim_get_current_buf())
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(event)
      local bufnr = event.buf ---@type integer
      -- `BufWipeout` also fires before a rename. Defer the check so state is
      -- released only after actual buffer destruction.
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
          attachments[bufnr] = nil
        end
      end)
    end,
  })

  M.refresh(vim.api.nvim_get_current_buf())
end

return M
