---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.whichkey" ---@type string

---@class era.dressing.whichkey
---@field public input                     era.dressing.whichkey.input
---@field public state                     era.dressing.whichkey.state
---@field public tree                      era.dressing.whichkey.tree
---@field public util                      era.dressing.whichkey.util
---@field public view                      era.dressing.whichkey.view
local M = {}

local initialized = false ---@type boolean

---@type table<string, string>
local __mods__ = {
  input = "era.dressing.whichkey.input",
  state = "era.dressing.whichkey.state",
  tree = "era.dressing.whichkey.tree",
  util = "era.dressing.whichkey.util",
  view = "era.dressing.whichkey.view",
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

---Setup which-key with default configuration
---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  M.state.setup()

  stl.fn.observe({ dot.context.plugin.which_key }, function()
    local enabled = dot.context.plugin.which_key:snapshot() ---@type boolean
    if enabled then
      M.state.enable()
    else
      M.state.disable()
    end
  end, false)
end

---Add mappings
---@param mappings                       era.dressing.whichkey.IMapping | era.dressing.whichkey.IMapping[]
---@param opts                           ?era.dressing.whichkey.IAddOpts
---@return nil
function M.add(mappings, opts)
  M.state.add(mappings, opts)
end

---Show which-key manually
---@param opts                           ?era.dressing.whichkey.IShowOpts
---@return nil
function M.show(opts)
  if not M.state.ready then
    return
  end
  opts = opts or {}
  M.state.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  M.state.mode = opts.mode or M.util.get_mapmode()
  M.state.keys = opts.keys or ""
  M.view.render()
end

---Hide which-key
---@return nil
function M.hide()
  M.input.stop()
end

---Check if which-key is visible
---@return boolean
function M.is_visible()
  return M.state.winnr ~= nil
end

return M
