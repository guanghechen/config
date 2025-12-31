---@class era.m.wk
---@field public input                     era.m.wk.input
---@field public state                     era.m.wk.state
---@field public tree                      era.m.wk.tree
---@field public util                      era.m.wk.util
---@field public view                      era.m.wk.view
local M = {}

---@type table<string, string>
local __mods__ = {
  input = "era.m.wk.input",
  state = "era.m.wk.state",
  tree = "era.m.wk.tree",
  util = "era.m.wk.util",
  view = "era.m.wk.view",
}

setmetatable(M, {
  __index = function(t, k)
    local mod = __mods__[k]
    if mod then
      local loaded = require(mod)
      rawset(t, k, loaded)
      return loaded
    end
    return rawget(t, k)
  end,
})

---@type boolean
M.ready = false

---Setup which-key with default configuration
function M.dressing()
  M.state.setup()
end

---Add mappings
---@param mappings                       era.m.wk.IMapping | era.m.wk.IMapping[]
---@param opts                           era.m.wk.IAddOpts?
function M.add(mappings, opts)
  M.state.add(mappings, opts)
end

---Show which-key manually
---@param opts                           era.m.wk.IShowOpts?
function M.show(opts)
  if not M.ready then
    return
  end
  opts = opts or {}
  M.state.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  M.state.mode = opts.mode or M.util.get_mapmode()
  M.state.keys = opts.keys or ""
  M.view.render()
end

---Hide which-key
function M.hide()
  M.input.stop()
end

---Check if which-key is visible
---@return boolean
function M.is_visible()
  return M.state.winnr ~= nil
end

return M
