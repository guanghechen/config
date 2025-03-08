local __module_name__ = "fml.action.toggle" ---@type string

local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local Observable = require("eve.collection.observable")
local state = require("eve.state")
local command = require("eve.command")

local select = require("fml.fn.select")

---@type table<string, eve.collection.IObservable>
local flags = {
  ---flight
  flight_ai = state.flight.ai,
  flight_autoformat = state.flight.autoformat,
  flight_autoload = state.flight.autoload,
  flight_autosave = state.flight.autosave,
  flight_devmode = state.flight.devmode,
  flight_dressing_hipairs = state.flight.dressing_hipairs,
  flight_dressing_illumniate = state.flight.dressing_illumniate,
  flight_dressing_input = state.flight.dressing_input,
  flight_dressing_select = state.flight.dressing_select,
  flight_dressing_winsep_fixed = state.flight.dressing_winsep_fixed,
  flight_dressing_winsep_float = state.flight.dressing_winsep_float,
  flight_gitdiff_expand_all = state.flight.gitdiff_expand_all,

  ---lsp
  lsp_code_lens = state.lsp.code_lens,
  lsp_inlay_hints = state.lsp.inlay_hints,
  lsp_spellcheck = state.lsp.spellcheck,

  ---ux
  ux_relativenumber = state.option.relativenumber,
  ux_username = state.theme.username,
  ux_transparency = state.theme.transparency,

  ---plugin
  plugin_render_markdown = state.plugin.render_markdown,
  plugin_smear_cursor = state.plugin.smear_cursor,
  plugin_treesitter_context = state.plugin.treesitter_context,
}

---@class fml.action.toggle.IItem
---@field public title                  string
---@field public snapshot               fun(context: eve.command.IContext): string, string
---@field public action                 fun(context: eve.command.IContext): nil

local ai_providers = command.definitions.toggle.ai_provider.candidates ---@type string[]
local themes = command.definitions.toggle.theme.candidates ---@type string[]

---@type table<string, fml.action.toggle.IItem>
local toggle_item_map = {
  ai_provider = {
    title = "ai_provider",
    snapshot = function()
      local provider = state.flight.ai_provider:snapshot() ---@type string
      return provider, "String"
    end,
    action = function(context)
      command.execute(command.definitions.toggle.ai_provider.uuid, context)
    end,
  },
  hipatterns_local = {
    title = "hipatterns (local)",
    snapshot = function(context)
      local enabled = require("mini.hipatterns").is_buf_enabled(context.bufnr) ---@type boolean
      return enabled and "true" or "false", "Boolean"
    end,
    action = function(context)
      require("mini.hipatterns").toggle(context.bufnr)
    end,
  },
  lsp_python_venv = {
    title = "python venv",
    snapshot = function()
      local venv_path = state.lsp.python_venv_path:snapshot() ---@type string
      if venv_path == nil then
        return "nil", "Keyword"
      end
      return venv_path, "String"
    end,
    action = function(context)
      command.execute(command.definitions.lsp.select_python_venv.uuid, context)
    end,
  },
  markdown_local = {
    title = "markdown (local)",
    snapshot = function(context)
      local ok, render_markdown_state = pcall(require, "render-markdown.state")
      if not ok then
        return "Unknown", "Boolean"
      end

      local flag = state.plugin.render_markdown:snapshot() ---@type boolean
      local enabled = flag and render_markdown_state.get(context.bufnr).enabled == true
      return enabled and "true" or "false", "Boolean"
    end,
    action = function(context)
      local ok, render_markdown = pcall(require, "render-markdown")
      if ok then
        state.plugin.render_markdown:next(true)
        vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
        render_markdown.buf_toggle()
      end
    end,
  },
  maximize = {
    title = "maximize",
    snapshot = function()
      return "", "String"
    end,
    action = function(context)
      command.execute(command.definitions.toggle.maximize.uuid, context)
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
      local scheme = state.theme.get_scheme(theme) ---@type eve.t.theme.IScheme|nil
      return scheme and scheme.variant or "", "String"
    end,
    action = function()
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

for name, observable in pairs(flags) do
  toggle_item_map[name] = {
    title = name,
    snapshot = function()
      local enabled = observable:snapshot() ---@type boolean
      return enabled and "true" or "false", "Boolean"
    end,
    action = function()
      local enabled = observable:snapshot() ---@type boolean
      observable:next(not enabled)
    end,
  }
end

local toggle_item_names = vim.tbl_keys(toggle_item_map) ---@type string[]
table.sort(toggle_item_names)

---@param theme                         string
---@return nil
local function apply_theme(theme)
  if not vim.list_contains(themes, theme) then
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
  candidates = toggle_item_names,
}, true)

---@class fml.action.ux
local M = {}

---@param context                       eve.command.IContext
---@param arg                           string|nil
---@return nil
function M.list(context, arg)
  local flag_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if toggle_item_map[flag_name] ~= nil then
    local item = toggle_item_map[flag_name] ---@type fml.action.toggle.IItem
    item.action(context)
  else
    select({
      title = "Toggle Select",
      flag_fuzzy = true,
      flag_regex = false,
      input = Observable.from_value(flag_name),
      dimension = {
        row = 3,
        width = 64,
        max_height = 40,
      },
      multiple = false,
      fetch_items = function()
        local items = {} ---@type fml.ux.select.IItem[]
        for _, flag in ipairs(toggle_item_names) do
          local item = toggle_item_map[flag] ---@type fml.action.toggle.IItem
          items[#items + 1] = { uuid = flag, text = item.title, data = item }
        end
        return items
      end,
      render_item = function(item, match)
        local flag_item = toggle_item_map[item.uuid] ---@type fml.action.toggle.IItem
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
      on_confirm = function(widget, items)
        if #items == 1 then
          local item = items[1] ---@type fml.ux.select.IItem
          widget:close()
          item.data.action(context)
        end
      end,
    })
  end
end

---@param context                       eve.command.IContext
---@param arg                           string|nil
---@return nil
---@diagnostic disable-next-line: unused-local
function M.toggle_ai_provider(context, arg)
  local ai_provider = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.list_contains(ai_providers, ai_provider) then
    state.flight.ai_provider:next(ai_provider)
  else
    select({
      title = "Toggle ai provider",
      flag_fuzzy = true,
      flag_regex = false,
      input = Observable.from_value(ai_provider),
      dimension = {
        row = 5,
        width = 50,
      },
      multiple = false,
      get_present = function()
        return state.flight.ai_provider:snapshot() ---@type eve.e.AiProvider
      end,
      fetch_items = function()
        local items = {} ---@type fml.ux.select.IItem[]
        for _, flight in ipairs(ai_providers) do
          items[#items + 1] = { uuid = flight, text = flight }
        end
        return items
      end,
      render_item = function(item, match)
        local text = item.uuid ---@type string
        local highlights = { { coll = 0, colr = -1, hlname = "String" } } ---@type eve.t.IHighlightInline[]
        for _, piece in ipairs(match.matches) do
          highlights[#highlights + 1] = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
        end
        return text, highlights
      end,
      on_confirm = function(widget, items)
        if #items == 1 then
          local item = items[1] ---@type fml.ux.select.IItem
          widget:close()
          state.flight.ai_provider:next(item.uuid)
        end
      end,
    })
  end
end

---@param context                       eve.command.IContext
---@return nil
function M.toggle_maximize(context)
  local winnr_cur = vim.api.nvim_tabpage_get_win(context.tabnr) ---@type integer
  if state.status.maximized_winnrs[winnr_cur] then
    state.status.maximized_winnrs[winnr_cur] = nil
    vim.api.nvim_win_close(winnr_cur, true)
    return
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(context.tabnr) ---@type integer[]
  local winnr_maximized = nil ---@type integer|nil
  for _, winnr in ipairs(winnrs) do
    if state.status.maximized_winnrs[winnr] then
      winnr_maximized = winnr
      break
    end
  end

  if winnr_maximized ~= nil and vim.api.nvim_win_is_valid(winnr_maximized) then
    vim.api.nvim_tabpage_set_win(context.tabnr, winnr_maximized)
    return
  end

  local bufnr = context.bufnr ---@type integer
  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    local winnr = vim.api.nvim_open_win(bufnr, false, {
      relative = "editor",
      anchor = "NW",
      width = vim.o.columns - 2,
      height = vim.o.lines - 2,
      row = 1,
      col = 1,
      focusable = true,
      title = " MAXIMIZED ",
      title_pos = "center",
      border = "rounded",
      style = "minimal",
    })
    vim.wo[winnr].number = true
    vim.wo[winnr].relativenumber = true
    vim.wo[winnr].signcolumn = "yes"
    vim.wo[winnr].wrap = false

    state.status.maximized_winnrs[winnr] = true
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_tabpage_set_win(context.tabnr, winnr)
  end
end

---@param context                       eve.command.IContext
---@param arg                           unknown|nil
---@return nil
---@diagnostic disable-next-line: unused-local
function M.toggle_theme(context, arg)
  local theme_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.list_contains(themes, theme_name) then
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
      multiple = false,
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
      on_confirm = function(widget, items)
        if #items == 1 then
          local item = items[1] ---@type fml.ux.select.IItem
          widget:close()
          apply_theme(item.uuid)
        end
      end,
    })
  end
end

return M
