local __module_name__ = "fml.action.toggle" ---@type string

local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local Observable = require("eve.collection.observable")

local command = require("eve.command")
local state = require("eve.state")
local select = require("fml.fn.select")

---@class fml.action.toggle.IItem
---@field public title                  string
---@field public snapshot               fun(context: eve.command.IContext): string, string
---@field public action                 fun(context: eve.command.IContext): nil

local flights = command.definitions.toggle.flight.candidates ---@type string[]
local themes = command.definitions.toggle.theme.candidates ---@type string[]

---@param flight                        string
---@return nil
local function toggle_flight(flight)
  local observable = state.flight[flight] ---@type eve.collection.IObservable|nil
  if observable ~= nil then
    local enabled = not observable:snapshot() ---@type boolean
    observable:next(enabled)

    reporter.info({
      from = __module_name__,
      subject = "toggle_flight",
      message = flight .. " flight has been " .. (enabled and "enabled" or "disabled") .. ".",
    })
  else
    reporter.error({
      from = __module_name__,
      subject = "toggle_flight",
      message = "Unknown flight.",
      details = { flight = flight },
    })
  end
end

---@type table<string, fml.action.toggle.IItem>
local flag_map = {
  flight = {
    title = "flight",
    snapshot = function()
      return "", "String"
    end,
    action = function(context)
      command.execute(command.definitions.toggle.flight.uuid, context)
    end,
  },
  relativenumber = {
    title = "relativenumber",
    snapshot = function()
      local observable = state.option.relativenumber ---@type eve.collection.IObservable
      local flag = observable:snapshot()
      return flag and "true" or "false", "Boolean"
    end,
    action = function(context)
      command.execute(command.definitions.toggle.relativenumber.uuid, context)
    end,
  },
  relativenumber_local = {
    title = "relativenumber (local)",
    snapshot = function(context)
      local winnr = context.winnr ---@type integer
      local flag = vim.wo[winnr].relativenumber ---@type boolean
      return flag and "true" or "false", "Boolean"
    end,
    action = function(context)
      local winnr = context.winnr ---@type integer
      local flag = vim.wo[winnr].relativenumber ---@type boolean
      vim.wo[winnr].relativenumber = not flag
    end,
  },
  theme = {
    title = "theme",
    snapshot = function()
      local theme = state.theme.theme:snapshot() ---@type eve.e.Theme
      return theme, "String"
    end,
    action = function(context)
      command.execute(command.definitions.toggle.theme.uuid, context)
    end,
  },
  theme_variant = {
    title = "theme variant",
    snapshot = function()
      local theme = state.theme.theme:snapshot() ---@type eve.e.Theme
      local scheme = require("eve.theme").get_scheme(theme) ---@type eve.t.theme.IScheme|nil
      return scheme and scheme.variant or "", "String"
    end,
    action = function(context)
      command.execute(command.definitions.toggle.theme_variant.uuid, context)
    end,
  },
  transparency = {
    title = "theme transparency",
    snapshot = function()
      local observable = state.theme.transparency ---@type eve.collection.IObservable
      local flag = observable:snapshot()
      return flag and "true" or "false", "Boolean"
    end,
    action = function(context)
      command.execute(command.definitions.toggle.transparency.uuid, context)
    end,
  },
  wrap_local = {
    title = "wrap (local)",
    snapshot = function(context)
      local winnr = context.winnr ---@type integer
      local flag = vim.wo[winnr].wrap ---@type boolean
      return flag and "true" or "false", "Boolean"
    end,
    action = function(context)
      local winnr = context.winnr ---@type integer
      local flag = vim.wo[winnr].wrap ---@type boolean
      vim.wo[winnr].wrap = not flag
    end,
  },
}

local flags = vim.tbl_keys(flag_map) ---@type string[]
table.sort(flags)

---@param theme                         string
---@return nil
local function apply_theme(theme)
  if not vim.tbl_contains(themes, theme) then
    reporter.error({
      from = __module_name__,
      subject = "apply_theme",
      message = "Unknown theme.",
      details = { theme = theme },
    })
    return
  end

  local app_home = path.locate_app_config_home("guanghechen")
  local script_path = path.join(app_home, "config/theme/apply_theme.mjs")
  local ok, error = pcall(function()
    vim.fn.system({ "node", script_path, theme })
  end)
  if not ok then
    reporter.error({
      from = __module_name__,
      subject = "apply_theme",
      message = "Failed to toggle theme.",
      details = { theme = theme, app_home = app_home, script_path = script_path, error = error },
    })
  end
end

command.define({
  uuid = command.definitions.toggle.list.uuid,
  desc = command.definitions.toggle.list.desc,
  nargs = "?",
  candidates = flags,
}, true)

---@class fml.action.ux
local M = {}

---@param context                       eve.command.IContext
---@param arg                           string|nil
---@return nil
function M.list(context, arg)
  local flag_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if flag_map[flag_name] ~= nil then
    local item = flag_map[flag_name] ---@type fml.action.toggle.IItem
    item.action(context)
  else
    select({
      title = "Toggle Select",
      flag_fuzzy = true,
      flag_regex = false,
      input = Observable.from_value(flag_name),
      dimension = {
        row = 5,
        width = 50,
      },
      fetch_items = function()
        local items = {} ---@type fml.ux.select.IItem[]
        for _, flag in ipairs(flags) do
          local item = flag_map[flag] ---@type fml.action.toggle.IItem
          items[#items + 1] = { uuid = item.title, text = flag, data = item }
        end
        return items
      end,
      render_item = function(item, match)
        local flag_item = flag_map[item.text] ---@type fml.action.toggle.IItem
        local text_flag, hln_flag = flag_item.snapshot(context)

        local width_padding = 32 ---@type integer
        local padding = string.rep(" ", width_padding - vim.api.nvim_strwidth(item.text)) ---@type string
        local text = item.text .. padding .. text_flag ---@type string

        ---@type eve.t.IHighlightInline[]
        local highlights = {
          { coll = width_padding, colr = width_padding + #text_flag, hlname = hln_flag },
        }

        for _, piece in ipairs(match.matches) do
          highlights[#highlights + 1] = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
        end
        return text, highlights
      end,
      on_confirm = function(item)
        item.data.action(context)
      end,
    })
  end
end

---@param context                       eve.command.IContext
---@param arg                           string|nil
---@return nil
---@diagnostic disable-next-line: unused-local
function M.toggle_flight(context, arg)
  local flight_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.tbl_contains(flights, flight_name) then
    toggle_flight(flight_name)
  else
    select({
      title = "Toggle flight",
      flag_fuzzy = true,
      flag_regex = false,
      input = Observable.from_value(flight_name),
      dimension = {
        row = 5,
        width = 50,
      },
      fetch_items = function()
        local items = {} ---@type fml.ux.select.IItem[]
        for _, flight in ipairs(flights) do
          items[#items + 1] = { uuid = flight, text = flight }
        end
        return items
      end,
      render_item = function(item, match)
        local flight = item.uuid ---@type string
        local observable = state.flight[flight] ---@type eve.collection.IObservable
        local enabled = observable:snapshot() ---@type boolean
        local text_enabled = enabled and "true" or "false" ---@type string

        local width_padding = 32 ---@type integer
        local padding = string.rep(" ", width_padding - vim.api.nvim_strwidth(flight)) ---@type string
        local text = flight .. padding .. text_enabled ---@type string

        ---@type eve.t.IHighlightInline[]
        local highlights = {
          { coll = width_padding, colr = width_padding + #text_enabled, hlname = "Boolean" },
        }

        for _, piece in ipairs(match.matches) do
          highlights[#highlights + 1] = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
        end
        return text, highlights
      end,
      on_confirm = function(item)
        local flight = item.uuid ---@type string
        toggle_flight(flight)
      end,
    })
  end
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.toggle_relativenumber(context)
  local observable = state.option.relativenumber ---@type eve.collection.IObservable
  local flag = observable:snapshot() ---@type boolean
  observable:next(not flag)
end

---@param context                       eve.command.IContext
---@param arg                           unknown|nil
---@return nil
---@diagnostic disable-next-line: unused-local
function M.toggle_theme(context, arg)
  local theme_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.tbl_contains(themes, theme_name) then
    apply_theme(theme_name)
  else
    select({
      title = "Select theme",
      flag_fuzzy = true,
      flag_regex = false,
      input = Observable.from_value(theme_name),
      dimension = {
        row = 5,
        width = 50,
      },
      get_present = function()
        local theme = state.theme.theme:snapshot() ---@type eve.e.Theme
        return theme
      end,
      fetch_items = function()
        local items = {} ---@type fml.ux.select.IItem[]
        for _, theme in ipairs(themes) do
          items[#items + 1] = { uuid = theme, text = theme }
        end
        return items
      end,
      on_confirm = function(item)
        local theme = item.uuid ---@type string
        apply_theme(theme)
      end,
    })
  end
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.toggle_theme_variant(context)
  local theme = state.theme.theme:snapshot() ---@type eve.e.Theme
  local app_home = path.locate_app_config_home("guanghechen")
  local script_path = path.join(app_home, "config/theme/toggle_theme.mjs")
  local ok, error = pcall(function()
    vim.fn.system({ "node", script_path, theme })
  end)
  if not ok then
    reporter.error({
      from = __module_name__,
      subject = "toggle_theme_variant",
      message = "Failed to toggle theme variant.",
      details = { theme = theme, app_home = app_home, script_path = script_path, error = error },
    })
  end
end

---@param context                       eve.command.IContext
---@return nil
function M.toggle_transparency(context)
  local observable = state.theme.transparency ---@type eve.collection.IObservable
  local flag = observable:snapshot() ---@type boolean
  observable:next(not flag)
  command.execute(command.definitions.ux.reload_theme.uuid, context, "force")
end

return M
