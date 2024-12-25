local __module_name__ = "ghc.action.toggle" ---@type string

local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local Observable = require("eve.lib.collection.observable")
local command = require("eve.lib.command")
local state = require("eve.state")

---@class ghc.action.toggle.IItem
---@field public uuid                   string
---@field public title                  string
---@field public snapshot               fun(): string, string

---@type table<string, ghc.action.toggle.IItem>
local flag_map = {
  flight = {
    uuid = command.definitions.toggle.flight.uuid,
    title = "flight",
    snapshot = function()
      return "", "String"
    end,
  },
  relativenumber = {
    uuid = command.definitions.toggle.relativenumber.uuid,
    title = "relativenumber",
    snapshot = function()
      local observable = state.theme.relativenumber ---@type eve.lib.collection.IObservable
      local flag = observable:snapshot()
      return flag and "true" or "false", "Boolean"
    end,
  },
  theme = {
    uuid = command.definitions.toggle.theme.uuid,
    title = "theme",
    snapshot = function()
      local theme = state.theme.theme:snapshot() ---@type eve.e.Theme
      return theme, "String"
    end,
  },
  theme_variant = {
    uuid = command.definitions.toggle.theme_variant.uuid,
    title = "theme variant",
    snapshot = function()
      local theme = state.theme.theme:snapshot() ---@type eve.e.Theme
      local scheme = require("fml.ux.theme").get_scheme(theme) ---@type eve.lib.collection.theme.IScheme|nil
      return scheme and scheme.variant or "", "String"
    end,
  },
  transparency = {
    uuid = command.definitions.toggle.transparency.uuid,
    title = "theme transparency",
    snapshot = function()
      local observable = state.theme.transparency ---@type eve.lib.collection.IObservable
      local flag = observable:snapshot()
      return flag and "true" or "false", "Boolean"
    end,
  },
  wrap = {
    uuid = command.definitions.toggle.wrap.uuid,
    title = "wrap",
    snapshot = function()
      ---@diagnostic disable-next-line: undefined-field
      local flag = vim.opt_local.wrap:get() ---@type boolean
      return flag and "true" or "false", "Boolean"
    end,
  },
}

local flags = vim.tbl_keys(flag_map) ---@type string[]
table.sort(flags)

local flights = vim.tbl_keys(state.flight) ---@type string[]
table.sort(flights)

local themes = fml.ux.theme.themes ---@type eve.e.Theme[]

---@param flight                        string
---@return nil
local function toggle_flight(flight)
  local observable = state.flight[flight] ---@type eve.lib.collection.IObservable|nil
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

command
  .define({
    uuid = command.definitions.toggle.list.uuid,
    desc = command.definitions.toggle.list.desc,
    nargs = "?",
    candidates = flags,
  }, true)
  .define({
    uuid = command.definitions.toggle.flight.uuid,
    desc = command.definitions.toggle.flight.desc,
    nargs = "?",
    candidates = flights,
  }, true)
  .define({
    uuid = command.definitions.toggle.theme.uuid,
    desc = command.definitions.toggle.theme.desc,
    nargs = "?",
    candidates = themes,
  }, true)

---@class ghc.action.ux
local M = {}

---@return nil
function M.list(arg)
  local flag_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if flag_map[flag_name] ~= nil then
    local item = flag_map[flag_name] ---@type ghc.action.toggle.IItem
    command.execute(item.uuid)
  else
    fml.fn.select({
      title = "Toggle Select",
      flag_fuzzy = true,
      flag_regex = false,
      input = Observable.from_value(flag_name),
      dimension = {
        row = 5,
        width = 50,
      },
      fetch_items = function()
        local items = {} ---@type fml.t.ux.select.IItem[]
        for _, flag in ipairs(flags) do
          local flag_item = flag_map[flag] ---@type ghc.action.toggle.IItem
          items[#items + 1] = { uuid = flag_item.uuid, text = flag }
        end
        return items
      end,
      render_item = function(item, match)
        local flag_item = flag_map[item.text] ---@type ghc.action.toggle.IItem
        local text_flag, hln_flag = flag_item.snapshot()

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
        command.execute(item.uuid)
      end,
    })
  end
end

---@param arg                           string|nil
---@return nil
function M.toggle_flight(arg)
  local flight_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.tbl_contains(flights, flight_name) then
    toggle_flight(flight_name)
  else
    fml.fn.select({
      title = "Toggle flight",
      flag_fuzzy = true,
      flag_regex = false,
      input = Observable.from_value(flight_name),
      dimension = {
        row = 5,
        width = 50,
      },
      fetch_items = function()
        local items = {} ---@type fml.t.ux.select.IItem[]
        for _, flight in ipairs(flights) do
          items[#items + 1] = { uuid = flight, text = flight }
        end
        return items
      end,
      render_item = function(item, match)
        local flight = item.uuid ---@type string
        local observable = state.flight[flight] ---@type eve.lib.collection.IObservable
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

---@return nil
function M.toggle_relativenumber()
  local observable = state.theme.relativenumber ---@type eve.lib.collection.IObservable
  local flag = observable:snapshot() ---@type boolean

  vim.opt.relativenumber = not flag
  observable:next(not flag)
end

---@param arg                           unknown|nil
---@return nil
function M.toggle_theme(arg)
  local theme_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.tbl_contains(themes, theme_name) then
    apply_theme(theme_name)
  else
    fml.fn.select({
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
        local items = {} ---@type fml.t.ux.select.IItem[]
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

---@return nil
function M.toggle_theme_variant()
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

---@return nil
function M.toggle_transparency()
  local observable = state.theme.transparency ---@type eve.lib.collection.IObservable
  local flag = observable:snapshot() ---@type boolean
  observable:next(not flag)
  command.execute(command.definitions.ux.reload_theme.uuid, "force")
end

---@return nil
function M.toggle_wrap()
  ---@diagnostic disable-next-line: undefined-field
  local wrap = vim.opt_local.wrap:get() ---@type boolean
  vim.opt_local.wrap = not wrap
end

return M
