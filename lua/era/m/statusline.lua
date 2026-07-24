---@class era.m.statusline
local M = {}

local dirtier = dot.state.status.dirtier_statusline ---@type stl.c.Dirtier
local position = "f_sl" ---@type stl.t.NvimbarPositionEnum

local statusline ---@type era.m.nvimbar.Nvimbar

statusline = era.m.nvimbar.Nvimbar.new({
  name = "statusline",
  comp_sep = "  ",
  comp_sep_hlname = position .. "_bg",
  comp_sep_hlname_active = position .. "_bg",
  delay = 256,
  silent = function()
    local devmode = dot.context.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = stl.fn.falsy,
  on_fulfilled = function()
    local result = statusline:snapshot() or "" ---@type string
    vim.o.statusline = result
    dirtier:mark_clean()
  end,
})

statusline
  :place("left", era.m.nvimbar.component.host.username(position), 100)
  :place("left", era.m.nvimbar.component.nvim.mode(position), 100)
  :place("left", era.m.nvimbar.component.git.branch(position), 100)
  :place("left", era.m.nvimbar.component.file.readonly(position), 95)
  :place("left", era.m.nvimbar.component.file.format(position), 95)
  :place("left", era.m.nvimbar.component.file.indent(position), 95)
  :place("left", era.m.nvimbar.component.file.encoding(position), 100)
  :place("left", era.m.nvimbar.component.file.type(position))
  :place("left", era.m.nvimbar.component.file.size(position))
  :place("left", era.m.nvimbar.component.file.status(position))
  --
  :place("center", era.m.nvimbar.component.devmode.render_count(position), 100)
  --
  :place("right", era.m.nvimbar.component.nvim.pos(position), 100)
  :place("right", era.m.nvimbar.component.nvim.nr(position), 100)
  :place("right", era.m.nvimbar.component.nvim.pid(position), 100)
  :place("right", era.m.nvimbar.component.python.env(position), 100)
  :place("right", era.m.nvimbar.component.lsp.client(position), 100)
  :place("right", era.m.nvimbar.component.lint.status(position), 95)
  :place("right", era.m.nvimbar.component.ai.status(position), 95)
  :place("right", era.m.nvimbar.component.copilot.status(position), 95)
  :place("right", era.m.nvimbar.component.lsp.diagnostics(position), 95)
  :place("right", era.m.nvimbar.component.nvim.msg_mode(position), 95)
  :place("right", era.m.nvimbar.component.nvim.msg_command(position), 80)
  :place("right", era.m.nvimbar.component.nvim.msg_transient(position), 85)
  :place("right", era.m.nvimbar.component.nvim.msg_lsp(position), 90)

---@return nil
function M.dressing()
  local statusline_snapshot = statusline:render(true) ---@type string
  vim.o.statusline = statusline_snapshot
  dirtier:mark_clean()

  dirtier:subscribe(stl.c.Subscriber.new({
    on_next = function()
      if dirtier:is_dirty() then
        statusline:render()
      end
    end,
  }))

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = stl.nvim.fn.augroup("statusline_on_ModeChanged"),
    callback = function(evt)
      local m = evt.match ---@type string
      if string.sub(m, 1, 2) == "c:" or string.sub(m, #m - 1, #m) == ":c" then
        vim.schedule(function()
          local result = statusline:render(true) ---@type string
          vim.o.statusline = result
          vim.cmd("redraw")
        end)
      end
      statusline:render()
    end,
  })
end

return M
