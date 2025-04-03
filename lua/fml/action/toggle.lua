local __module_name__ = "fml.action.toggle" ---@type string

---@type table<string, table<string, eve.std.collection.IObservable<boolean>>>
local group_flags = {
  ---flight
  flight = {
    ai = eve.state.flight.ai,
    autoformat = eve.state.flight.autoformat,
    autoload = eve.state.flight.autoload,
    autosave = eve.state.flight.autosave,
    devmode = eve.state.flight.devmode,
    dressing_hipairs = eve.state.flight.dressing_hipairs,
    dressing_illumniate = eve.state.flight.dressing_illumniate,
    dressing_input = eve.state.flight.dressing_input,
    dressing_select = eve.state.flight.dressing_select,
    dressing_winsep_fixed = eve.state.flight.dressing_winsep_fixed,
    dressing_winsep_float = eve.state.flight.dressing_winsep_float,
    gitdiff_expand_all = eve.state.flight.gitdiff_expand_all,
  },

  ---lsp
  lsp = {
    code_lens = eve.state.lsp.code_lens,
    inlay_hints = eve.state.lsp.inlay_hints,
    spellcheck = eve.state.lsp.spellcheck,
  },

  ---ux
  ux = {
    relativenumber = eve.state.option.relativenumber,
    username = eve.state.theme.username,
    transparency = eve.state.theme.transparency,
  },

  ---plugin
  plugin = {
    render_markdown = eve.state.plugin.render_markdown,
    smear_cursor = eve.state.plugin.smear_cursor,
    treesitter_context = eve.state.plugin.treesitter_context,
  },
}

---@class fml.action.toggle.IItem
---@field public title                  string
---@field public group                  string|nil
---@field public snapshot               fun(): string, string
---@field public action                 fun(): nil

local ai_providers = eve.command.definitions.toggle.ai_provider.candidates ---@type string[]
local themes = eve.command.definitions.toggle.theme.candidates ---@type string[]

---@type table<string, table<string, fml.action.toggle.IItem>>
local group_items = {
  flight = {
    ai_provider = {
      title = "ai_provider",
      snapshot = function()
        local provider = eve.state.flight.ai_provider:snapshot() ---@type string
        return provider, "String"
      end,
      action = function()
        eve.command.execute(eve.command.definitions.toggle.ai_provider.uuid)
      end,
    },
  },
  _local = {
    fileformat = {
      title = "fileformat",
      snapshot = function()
        local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "String"
        end
        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer|nil
        local fileformat = vim.bo[bufnr].fileformat ---@type string
        return fileformat, "String"
      end,
      action = function()
        local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer
        local filepath = eve.path.relative(eve.path.cwd(), vim.api.nvim_buf_get_name(bufnr), false) ---@type string
        local fileformat_cur = vim.bo[bufnr].fileformat ---@type string

        eve.ux.fn.select({
          title = string.format("Toggle fileformat (%s)", filepath),
          flag_fuzzy = true,
          flag_regex = false,
          dimension = {
            row = 3,
            width = 64,
            max_height = math.max(math.floor(vim.o.lines * 0.6), 24),
          },
          multiple = false,
          get_present = function()
            return fileformat_cur ---@type string
          end,
          fetch_items = function()
            ---@type eve.ux.select.IItem[]
            local items = {
              { uuid = "dos", text = "dos  (CRLF)" },
              { uuid = "mac", text = "mac  (CR)" },
              { uuid = "unix", text = "unix (LF)" },
            }
            return items
          end,
          render_item = function(item, match)
            local highlights = {} ---@type eve.t.IHighlightInline[]
            for _, piece in ipairs(match.matches) do
              highlights[#highlights + 1] = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
            end
            return item.text, highlights
          end,
          on_confirm = function(widget, items)
            widget:close()
            if #items == 1 and vim.api.nvim_buf_is_valid(bufnr) then
              local fileformat = items[1].uuid ---@type string
              vim.bo[bufnr].fileformat = fileformat
            end
          end,
        })
      end,
    },
    hipatterns = {
      title = "hipatterns",
      snapshot = function()
        return "unknown", "Boolean"
      end,
      action = function()
        local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
        if winnr_command ~= nil then
          local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer
          require("mini.hipatterns").toggle(bufnr)
        end
      end,
    },
    markdown = {
      title = "markdown",
      snapshot = function()
        return "unknown", "Boolean"
      end,
      action = function()
        local ok, render_markdown = pcall(require, "render-markdown")
        if ok then
          eve.state.plugin.render_markdown:next(true)
          eve.state.editor.focus_win_fixed()
          render_markdown.buf_toggle()
        end
      end,
    },
    relativenumber = {
      title = "relativenumber",
      snapshot = function()
        local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "Boolean"
        end

        local flag = vim.wo[winnr_command].relativenumber ---@type boolean
        return flag and "true" or "false", "Boolean"
      end,
      action = function()
        local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local flag = vim.wo[winnr_command].relativenumber ---@type boolean
        vim.wo[winnr_command].relativenumber = not flag
      end,
    },
    wrap = {
      title = "wrap",
      snapshot = function()
        local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "Boolean"
        end

        local flag = vim.wo[winnr_command].wrap ---@type boolean
        return flag and "true" or "false", "Boolean"
      end,
      action = function()
        local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local flag = vim.wo[winnr_command].wrap ---@type boolean
        vim.wo[winnr_command].wrap = not flag
      end,
    },
  },
  lsp = {
    python_debug_host = {
      title = "python debug host",
      snapshot = function()
        local host = eve.state.lsp.python_debug_host:snapshot() ---@type string
        if host == nil then
          return "nil", "Keyword"
        end
        return host, "String"
      end,
      action = function()
        local default_host = eve.state.lsp.python_debug_host:snapshot() or "" ---@type string
        local input_host = vim.fn.input("host [" .. default_host .. "]", default_host)
        local host = #input_host > 0 and input_host or default_host ---@type string
        eve.state.lsp.python_debug_host:next(host)
      end,
    },
    python_debug_port = {
      title = "python debug port",
      snapshot = function()
        local port = eve.state.lsp.python_debug_port:snapshot() ---@type integer
        if port == nil then
          return "nil", "Keyword"
        end
        return tostring(port), "Number"
      end,
      action = function()
        local default_port = eve.state.lsp.python_debug_port:snapshot() or 0 ---@type integer
        local input_port = vim.fn.input("port [" .. tostring(default_port) .. "]", tostring(default_port))
        local port = #input_port > 0 and tonumber(input_port) or default_port ---@type integer
        eve.state.lsp.python_debug_port:next(port)
      end,
    },
    python_venv = {
      title = "python venv path",
      snapshot = function()
        local venv_path = eve.state.lsp.python_venv_path:snapshot() ---@type string
        if venv_path == nil then
          return "nil", "Keyword"
        end
        return venv_path, "String"
      end,
      action = function()
        eve.command.execute(eve.command.definitions.lsp.select_python_venv.uuid)
      end,
    },
  },
  theme = {
    theme = {
      title = "theme",
      snapshot = function()
        local theme = eve.state.theme.theme:snapshot() ---@type eve.e.Theme
        return theme, "String"
      end,
      action = function()
        eve.command.execute(eve.command.definitions.toggle.theme.uuid)
      end,
    },
    theme_variant = {
      title = "theme variant",
      snapshot = function()
        local theme = eve.state.theme.theme:snapshot() ---@type eve.e.Theme
        local scheme = eve.state.theme.get_scheme(theme) ---@type eve.t.theme.IScheme|nil
        return scheme and scheme.variant or "", "String"
      end,
      action = function()
        local theme = eve.state.theme.theme:snapshot() ---@type eve.e.Theme
        local app_home = eve.path.locate_app_config_home("guanghechen")
        local script_path = eve.path.join(app_home, "config/theme/toggle_theme.mjs")
        local ok, error = pcall(function()
          vim.fn.system({ "node", script_path, theme })
        end)
        if not ok then
          eve.reporter.error({
            from = __module_name__,
            subject = "toggle_theme_variant",
            message = "Failed to toggle theme variant.",
            details = { theme = theme, app_home = app_home, script_path = script_path, error = error },
          })
        end
      end,
    },
  },
  misc = {
    maximize = {
      title = "maximize",
      snapshot = function()
        return "", "String"
      end,
      action = function()
        eve.command.execute(eve.command.definitions.toggle.maximize.uuid)
      end,
    },
  },
}

local toggle_item_map = {} ---@type table<string, fml.action.toggle.IItem>
local toggle_item_names = {} ---@type string[]

do
  for g, flags in pairs(group_flags) do
    local group = g ---@type string|nil
    if g == "misc" then
      group = nil
    elseif g:sub(1, 1) == "_" then
      group = g:sub(2)
    end

    for name, observable in pairs(flags) do
      local title = name ---@type string
      name = group and name .. "_" .. group or name ---@type string
      toggle_item_map[name] = {
        title = title,
        group = group,
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
  end
  for g, items in pairs(group_items) do
    local group = g ---@type string|nil
    if g == "misc" then
      group = nil
    elseif g:sub(1, 1) == "_" then
      group = g:sub(2)
    end

    for name, item in pairs(items) do
      name = group and name .. "_" .. group or name ---@type string
      toggle_item_map[name] = {
        title = item.title,
        group = group ~= "misc" and group or nil,
        snapshot = item.snapshot,
        action = item.action,
      }
    end
  end

  toggle_item_names = vim.tbl_keys(toggle_item_map) ---@type string[]
  table.sort(toggle_item_names, function(x, y)
    local vx = toggle_item_map[x] ---@type fml.action.toggle.IItem
    local vy = toggle_item_map[y] ---@type fml.action.toggle.IItem

    if vx.group == vy.group then
      return vx.title < vy.title
    end

    if vx.group == nil then
      return false
    end

    if vy.group == nil then
      return true
    end

    return vx.group < vy.group
  end)
end

---@param theme                         string
---@return nil
local function apply_theme(theme)
  if not vim.list_contains(themes, theme) then
    eve.reporter.error({
      from = __module_name__,
      subject = "apply_theme",
      message = "Unknown theme.",
      details = { theme = theme },
    })
    return
  end

  local app_home = eve.path.locate_app_config_home("guanghechen")
  local script_path = eve.path.join(app_home, "config/theme/apply_theme.mjs")
  local ok, error = pcall(function()
    vim.fn.system({ "node", script_path, theme })
  end)
  if not ok then
    eve.reporter.error({
      from = __module_name__,
      subject = "apply_theme",
      message = "Failed to toggle theme.",
      details = { theme = theme, app_home = app_home, script_path = script_path, error = error },
    })
  end
end

eve.command.define({
  uuid = eve.command.definitions.toggle.list.uuid,
  desc = eve.command.definitions.toggle.list.desc,
  nargs = "?",
  candidates = toggle_item_names,
}, true)

---@class fml.action.ux
local M = {}

---@param arg                           string|nil
---@return nil
function M.list(arg)
  local flag_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if toggle_item_map[flag_name] ~= nil then
    local item = toggle_item_map[flag_name] ---@type fml.action.toggle.IItem
    item.action()
  else
    eve.ux.fn.select({
      title = "Toggle Select",
      flag_fuzzy = true,
      flag_regex = false,
      input = eve.std.Observable.from_value(flag_name),
      dimension = {
        row = 3,
        width = 64,
        max_height = math.max(math.floor(vim.o.lines * 0.6), 24),
      },
      multiple = false,
      fetch_items = function()
        local items = {} ---@type eve.ux.select.IItem[]
        for _, flag in ipairs(toggle_item_names) do
          local item = toggle_item_map[flag] ---@type fml.action.toggle.IItem
          items[#items + 1] = { uuid = flag, text = item.title, data = item }
        end
        return items
      end,
      render_item = function(item, match)
        local flag_item = item.data ---@type fml.action.toggle.IItem
        local text_group = flag_item.group or "" ---@type string
        local text_flag, hln_flag = flag_item.snapshot()

        local w_p_title = 24 ---@type integer
        local w_p_group = 12 ---@type integer
        local offset = w_p_title + w_p_group + 2 ---@type integer

        local text = string.format(
          "%s %s %s",
          eve.string.pad_end(text_group, w_p_group, " "),
          eve.string.pad_end(flag_item.title, w_p_title, " "),
          text_flag
        ) ---@type string

        ---@type eve.t.IHighlightInline[]
        local highlights = {
          { coll = 0, colr = #text_group + 1, hlname = "Special" },
          { coll = offset, colr = offset + #text_flag, hlname = hln_flag },
        }

        for _, piece in ipairs(match.matches) do
          highlights[#highlights + 1] =
            { coll = w_p_group + 1 + piece.l, colr = w_p_group + 1 + piece.r, hlname = "f_us_main_match" }
        end
        return text, highlights
      end,
      on_confirm = function(widget, items)
        if #items == 1 then
          local item = items[1] ---@type eve.ux.select.IItem
          widget:close()
          item.data.action()
        end
      end,
    })
  end
end

---@param arg                           string|nil
---@return nil
function M.toggle_ai_provider(arg)
  local ai_provider = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.list_contains(ai_providers, ai_provider) then
    eve.state.flight.ai_provider:next(ai_provider)
  else
    eve.ux.fn.select({
      title = "Toggle ai provider",
      flag_fuzzy = true,
      flag_regex = false,
      input = eve.std.Observable.from_value(ai_provider),
      dimension = {
        row = 5,
        width = 50,
      },
      multiple = false,
      get_present = function()
        return eve.state.flight.ai_provider:snapshot() ---@type eve.e.AiProvider
      end,
      fetch_items = function()
        local items = {} ---@type eve.ux.select.IItem[]
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
          local item = items[1] ---@type eve.ux.select.IItem
          widget:close()
          eve.state.flight.ai_provider:next(item.uuid)
        end
      end,
    })
  end
end

---@return nil
function M.toggle_maximize()
  local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
  if winnr_command == nil then
    return
  end

  if eve.state.status.maximized_winnrs[winnr_command] then
    eve.state.status.maximized_winnrs[winnr_command] = nil
    vim.api.nvim_win_close(winnr_command, true)
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local winnr_maximized = nil ---@type integer|nil
  for _, winnr in ipairs(winnrs) do
    if eve.state.status.maximized_winnrs[winnr] then
      winnr_maximized = winnr
      break
    end
  end

  if winnr_maximized ~= nil and vim.api.nvim_win_is_valid(winnr_maximized) then
    vim.api.nvim_tabpage_set_win(tabnr, winnr_maximized)
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer
  if eve.editor.is_buf_valid(bufnr) then
    local winnr = vim.api.nvim_open_win(bufnr, false, {
      relative = "editor",
      anchor = "NW",
      width = vim.o.columns - 2,
      height = vim.o.lines - 4,
      row = 1,
      col = 0,
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

    vim.w[winnr][eve.var.Names.FLAG_SOURCEFILE] = eve.editor.is_win_sourcefile(winnr_command)
    eve.state.status.maximized_winnrs[winnr] = true
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_tabpage_set_win(tabnr, winnr)
  end
end

---@param arg                           unknown|nil
---@return nil
function M.toggle_theme(arg)
  local theme_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.list_contains(themes, theme_name) then
    apply_theme(theme_name)
  else
    eve.ux.fn.select({
      title = "Select theme",
      flag_fuzzy = true,
      flag_regex = false,
      input = eve.std.Observable.from_value(theme_name),
      dimension = {
        row = 5,
        width = 50,
      },
      multiple = false,
      get_present = function()
        local theme = eve.state.theme.theme:snapshot() ---@type eve.e.Theme
        return theme
      end,
      fetch_items = function()
        local items = {} ---@type eve.ux.select.IItem[]
        for _, theme in ipairs(themes) do
          items[#items + 1] = { uuid = theme, text = theme }
        end
        return items
      end,
      on_confirm = function(widget, items)
        if #items == 1 then
          local item = items[1] ---@type eve.ux.select.IItem
          widget:close()
          apply_theme(item.uuid)
        end
      end,
    })
  end
end

return M
