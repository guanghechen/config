local __module_name__ = "era.dressing.statusline" ---@type string
local initialized = false ---@type boolean

---@class era.dressing.statusline
local M = {}

local dirtier = dot.state.status.dirtier_statusline ---@type stl.c.Dirtier
local c = era.m.nvimbar.component
local position = "f_sl" ---@type stl.t.NvimbarPositionEnum

local statusline ---@type era.m.nvimbar.Nvimbar

statusline = era.m.nvimbar.Nvimbar.new({
  name = "statusline",
  comp_sep = "  ",
  comp_sep_hlname = position .. "_bg",
  comp_sep_hlname_active = position .. "_bg",
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = stl.fn.falsy,
  on_fulfilled = function(result)
    if vim.o.statusline ~= result or vim.api.nvim_get_option_value("statusline", { scope = "local" }) ~= "" then
      vim.o.statusline = result
    end
    -- The built-in cmdline does not redraw after an asynchronous option update.
    if vim.api.nvim_get_mode().mode:sub(1, 1) == "c" then
      vim.cmd("redraw")
    end
  end,
})

statusline
  :place({
    position = "left",
    priority = 100,
    component = c.lazy(function()
      return c.host.username(position)
    end),
  })
  :place({
    position = "left",
    priority = 100,
    component = c.lazy(function()
      return c.nvim.mode(position)
    end),
  })
  :place({
    position = "left",
    priority = 100,
    component = c.lazy(function()
      return c.git.branch(position)
    end),
  })
  :place({
    position = "left",
    priority = 95,
    component = c.lazy(function()
      return c.file.readonly(position)
    end),
  })
  :place({
    position = "left",
    priority = 95,
    component = c.lazy(function()
      return c.file.format(position)
    end),
  })
  :place({
    position = "left",
    priority = 95,
    component = c.lazy(function()
      return c.file.indent(position)
    end),
  })
  :place({
    position = "left",
    priority = 100,
    component = c.lazy(function()
      return c.file.encoding(position)
    end),
  })
  :place({
    position = "left",
    component = c.lazy(function()
      return c.file.type(position)
    end),
  })
  :place({
    position = "left",
    component = c.lazy(function()
      return c.file.size(position)
    end),
  })
  :place({
    position = "left",
    component = c.lazy(function()
      return c.file.status(position)
    end),
  })
  --
  :place({
    position = "center",
    priority = 100,
    component = c.lazy(function()
      return c.devmode.render_count(position)
    end),
  })
  --
  :place({
    position = "right",
    priority = 100,
    component = c.lazy(function()
      return c.nvim.pos(position)
    end),
  })
  :place({
    position = "right",
    priority = 100,
    component = c.lazy(function()
      return c.nvim.nr(position)
    end),
  })
  :place({
    position = "right",
    priority = 100,
    component = c.lazy(function()
      return c.nvim.pid(position)
    end),
  })
  :place({
    position = "right",
    priority = 100,
    component = c.lazy(function()
      return c.python.env(position)
    end),
  })
  :place({
    position = "right",
    priority = 100,
    component = c.lazy(function()
      return c.lsp.client(position)
    end),
  })
  :place({
    position = "right",
    priority = 95,
    component = c.lazy(function()
      return c.lint.status(position)
    end),
  })
  :place({
    position = "right",
    priority = 95,
    component = c.lazy(function()
      return c.ai.status(position)
    end),
  })
  :place({
    position = "right",
    priority = 95,
    component = c.lazy(function()
      return c.lsp.diagnostics(position)
    end),
  })
  :place({
    position = "right",
    priority = 95,
    component = c.lazy(function()
      return c.nvim.msg_mode(position)
    end),
  })
  :place({
    position = "right",
    priority = 80,
    component = c.lazy(function()
      return c.nvim.msg_command(position)
    end),
  })
  :place({
    position = "right",
    priority = 85,
    component = c.lazy(function()
      return c.nvim.msg_transient(position)
    end),
  })
  :place({
    position = "right",
    priority = 90,
    component = c.lazy(function()
      return c.nvim.msg_lsp(position)
    end),
  })

--- Initialize once; dirty and mode events own subsequent refreshes.
---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  statusline:refresh()
  dirtier:mark_clean()

  dirtier:subscribe(stl.c.Subscriber.new({
    on_next = function()
      if not statusline:isdisposed() and dirtier:is_dirty() then
        dirtier:mark_clean()
        statusline:refresh()
      end
    end,
  }))

  local group = stl.nvim.fn.augroup(__module_name__)
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      vim.schedule(function()
        if not statusline:isdisposed() then
          statusline:refresh()
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function()
      statusline:dispose()
    end,
  })
end

return M
