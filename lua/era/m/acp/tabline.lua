---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.tabline" ---@type string

local txt = stl.nvim.fn.txt

---ACP tabline components and registration.
---@class era.m.acp.tabline
local M = {}

M.position = "f_tl" ---@type stl.t.NvimbarPositionEnum

----------------------------------------------------------------------------------------------------
-- Components
----------------------------------------------------------------------------------------------------

---Create title component showing provider name
---@return era.m.nvimbar.IRawComponent
function M.title_component()
  local position = M.position
  local hln_sep = position .. "_nvim_tabtype_sep" ---@type string
  local hln_text = position .. "_nvim_tabtype_text" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "acp:title",
    atomic = true,
    tight = false,
    render = function()
      local widget = era.m.acp.get_widget()
      if not widget then
        return "", "", true
      end

      local config = era.m.acp.config.provider_configs[widget.session.provider]
      local label = config and config.label or widget.session.provider
      local icon = "󰚩 " ---@type string

      local content = icon .. label ---@type string
      local text = stl.icon.symbols.sep_left .. content .. stl.icon.symbols.sep_right ---@type string

      ---@type string
      local hl_text = txt(stl.icon.symbols.sep_left, hln_sep)
        .. txt(content, hln_text)
        .. txt(stl.icon.symbols.sep_right, hln_sep)
      return text, hl_text, true
    end,
  }
  return component
end

----------------------------------------------------------------------------------------------------
-- Nvimbar factory
----------------------------------------------------------------------------------------------------

---Create ACP tabline nvimbar instance
---@return fun(): era.m.nvimbar.Nvimbar
function M.create_tabline()
  return function()
    local position = M.position
    local nvimbar ---@type era.m.nvimbar.Nvimbar

    nvimbar = era.m.nvimbar.Nvimbar.new({
      name = "tabline_acp",
      comp_sep = "",
      comp_sep_hlname = position .. "_bg",
      comp_sep_hlname_active = position .. "_bg",
      delay = 256,
      silent = function()
        return not dot.context.flight.devmode:snapshot()
      end,
      get_max_width = function()
        return vim.o.columns
      end,
      is_active = stl.fn.falsy,
      on_fulfilled = function()
        if vim.t.tabtype == stl.nvim.tab.TypeEnum.ACP then
          vim.o.tabline = nvimbar:snapshot()
        end
      end,
    })

    nvimbar
      :place("center", M.title_component(), 100)
      :place("right", era.m.nvimbar.component.nvim.tabs(position), 100)

    return nvimbar
  end
end

----------------------------------------------------------------------------------------------------
-- Registration
----------------------------------------------------------------------------------------------------

---Register nvimbar for ACP tabtype (idempotent)
---@return nil
function M.register()
  era.m.tabline.register(stl.nvim.tab.TypeEnum.ACP, M.create_tabline())
end

return M
