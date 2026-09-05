---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing" ---@type string

---@class era.dressing.__mods
local mods = {
  commentstring = "era.dressing.commentstring",
  foldtext = "era.dressing.foldtext",
  hipattern = "era.dressing.hipattern",
  indentline = "era.dressing.indentline",
  indentscope = "era.dressing.indentscope",
  notifier = "era.dressing.notifier",
  scroll = "era.dressing.scroll",
  statuscolumn = "era.dressing.statuscolumn",
  statusline = "era.dressing.statusline",
  tabline = "era.dressing.tabline",
  trailspace = "era.dressing.trailspace",
  ui_attach = "era.dressing.ui_attach",
  virtcolumn = "era.dressing.virtcolumn",
  winline = "era.dressing.winline",
  winsep = "era.dressing.winsep",
}

local load_times = {} ---@type table<string, number>

---@class era.dressing
---@field public __mods                 era.dressing.__mods
---@field public commentstring          era.dressing.commentstring
---@field public foldtext               era.dressing.foldtext
---@field public hipattern              era.dressing.hipattern
---@field public indentline             era.dressing.indentline
---@field public indentscope            era.dressing.indentscope
---@field public notifier               era.dressing.notifier
---@field public scroll                 era.dressing.scroll
---@field public statuscolumn           era.dressing.statuscolumn
---@field public statusline             era.dressing.statusline
---@field public tabline                era.dressing.tabline
---@field public trailspace             era.dressing.trailspace
---@field public ui_attach              era.dressing.ui_attach
---@field public virtcolumn             era.dressing.virtcolumn
---@field public winline                era.dressing.winline
---@field public winsep                 era.dressing.winsep
local M = setmetatable({
  __mods = mods,
}, {
  __index = function(t, k)
    local mod = mods[k] ---@type string|nil
    if mod == nil then
      return rawget(t, k)
    end
    return require(mod)
  end,
})

--- Modules own idempotence; record the first normal return of require and synchronous setup.
---@param names                         string[]
---@return nil
function M.setup(names)
  for _, name in ipairs(names) do
    local start_time = vim.uv.hrtime() ---@type integer
    M[name].dressing()
    if load_times[name] == nil then
      load_times[name] = (vim.uv.hrtime() - start_time) / 1e6
      vim.schedule(function()
        vim.api.nvim_exec_autocmds("User", { pattern = "DressingLoad", modeline = false, data = name })
      end)
    end
  end
end

---@return table<string, number>
function M.get_load_times()
  return vim.tbl_extend("force", {}, load_times)
end

return M
