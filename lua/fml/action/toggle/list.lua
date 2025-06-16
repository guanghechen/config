local __module_name__ = "fml.action.toggle.list" ---@type string

---@type table<string, integer>
local group_priorities = {
  behavior = 1,
  ["local"] = 2,
  ux = 3,
  flight = 4,
  lsp = 5,
  plugin = 6,
}

---@type table<string, table<string, std.collection.IObservable<boolean>>>
local group_flags = {
  ---behavior
  behavior = {
    auto_im = eve.context.behavior.auto_im,
    bufs_relative = eve.context.behavior.bufs_relative,
  },

  ---flight
  flight = {
    ai = eve.context.flight.ai,
    autoformat = eve.context.flight.autoformat,
    autoload = eve.context.flight.autoload,
    autosave = eve.context.flight.autosave,
    devmode = eve.context.flight.devmode,
    dressing_clipboard = eve.context.flight.dressing_clipboard,
    dressing_hipairs = eve.context.flight.dressing_hipairs,
    dressing_illumniate = eve.context.flight.dressing_illumniate,
    dressing_input = eve.context.flight.dressing_input,
    dressing_select = eve.context.flight.dressing_select,
    dressing_winsep = eve.context.flight.dressing_winsep,
    gitdiff_expand_all = eve.context.flight.gitdiff_expand_all,
  },

  ---lsp
  lsp = {
    code_lens = eve.context.lsp.code_lens,
    diagnostics_virt_lines = eve.context.lsp.diagnostics_virt_lines,
    inlay_hints = eve.context.lsp.inlay_hints,
    spellcheck = eve.context.lsp.spellcheck,
  },

  ---ux
  ux = {
    notification_paused = eve.status.notification_paused,
    relativenumber = eve.context.option.relativenumber,
    username = eve.context.theme.username,
    transparency = eve.context.theme.transparency,
  },

  ---plugin
  plugin = {
    render_markdown = eve.context.plugin.render_markdown,
    treesitter_context = eve.context.plugin.treesitter_context,
  },
}

---@class fml.action.toggle.IItem
---@field public title                  string
---@field public group                  string|nil
---@field public snapshot               fun(): string, string
---@field public action                 fun(): nil

---@class fml.action.toggle.IListItem : eve.ux.picker.composer.list.IItem
---@field public data                   fml.action.toggle.IItem

---@type table<string, table<string, fml.action.toggle.IItem>>
local group_items = {
  flight = {
    ai_provider = {
      title = "ai_provider",
      snapshot = function()
        local provider = eve.context.flight.ai_provider:snapshot() ---@type string
        return provider, "String"
      end,
      action = function()
        eve.command.execute(eve.command.definitions.toggle.ai_provider.uuid)
      end,
    },
  },
  ["local"] = {
    fileencoding = {
      title = "fileencoding",
      snapshot = function()
        local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "String"
        end
        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer|nil
        local encoding = vim.bo[bufnr].fileencoding ---@type string
        return encoding, "String"
      end,
      action = function()
        local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer
        local buftype = vim.bo[bufnr].buftype ---@type string
        local filename = std.path.basename(vim.api.nvim_buf_get_name(bufnr)) ---@type string
        if buftype ~= "" and buftype ~= "nowrite" then
          std.reporter.error({
            from = __module_name__,
            subject = "fileencoding_local",
            message = "Unsupported buftype",
            details = { winnr_command = winnr_command, bufnr = bufnr, buftype = buftype, filename = filename },
          })
          return
        end

        if vim.bo[bufnr].modified then
          std.reporter.error({
            from = __module_name__,
            subject = "fileencoding_local",
            message = "File is modified without save, please save it first.",
            details = { winnr_command = winnr_command, bufnr = bufnr, filename = filename },
          })
          return
        end

        local cwd_name = std.path.basename(std.path.cwd()) ---@type string
        local offset_right = #cwd_name + 4 ---@type integer
        local fileencoding_cur = vim.bo[bufnr].fileencoding ---@type string

        ---@return nil
        local function reopen()
          eve.ux.fn.select_encoding({
            present = fileencoding_cur,
            title = string.format("Reopen with encoding (%s)", filename),
            on_select = function(encoding)
              if encoding ~= nil then
                if vim.api.nvim_win_is_valid(winnr_command) then
                  vim.api.nvim_tabpage_set_win(0, winnr_command)
                end
                if vim.api.nvim_buf_is_valid(bufnr) then
                  vim.cmd("e ++enc=" .. encoding)
                end
              end
            end,
          })
        end

        ---@return nil
        local function resave()
          eve.ux.fn.select_encoding({
            present = fileencoding_cur,
            title = string.format("Resave with encoding (%s)", filename),
            on_select = function(encoding)
              if encoding ~= nil then
                if vim.api.nvim_win_is_valid(winnr_command) then
                  vim.api.nvim_tabpage_set_win(0, winnr_command)
                end
                if vim.api.nvim_buf_is_valid(bufnr) then
                  vim.api.nvim_buf_call(bufnr, function()
                    vim.bo[bufnr].fileencoding = encoding ---@type string
                    vim.cmd.write()
                  end)
                end
              end
            end,
          })
        end

        if vim.bo[bufnr].buftype == "nowrite" or vim.bo[bufnr].readonly then
          reopen()
        else
          eve.ux.SelectPopup
            .new({
              wincfg = {
                relative = "editor",
                anchor = "SE",
                width = 12,
                row = vim.o.lines - 1,
                col = vim.o.columns - offset_right,
              },
              items = {
                { uuid = "reopen", text = "reopen" },
                { uuid = "resave", text = "resave" },
              },
              on_select = function(widget, item)
                widget:destroy()

                if item ~= nil then
                  if item.uuid == "reopen" then
                    reopen()
                  else
                    resave()
                  end
                end
              end,
            })
            :focus()
        end
      end,
    },
    fileformat = {
      title = "fileformat",
      snapshot = function()
        local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "String"
        end
        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer|nil
        local fileformat = vim.bo[bufnr].fileformat ---@type string
        return fileformat, "String"
      end,
      action = function()
        local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer
        local buftype = vim.bo[bufnr].buftype ---@type string
        local filename = std.path.basename(vim.api.nvim_buf_get_name(bufnr)) ---@type string
        if buftype ~= "" and buftype ~= "nowrite" then
          std.reporter.error({
            from = __module_name__,
            subject = "fileformat_local",
            message = "Unsupported buftype",
            details = { winnr_command = winnr_command, bufnr = bufnr, buftype = buftype, filename = filename },
          })
          return
        end

        if vim.bo[bufnr].modified then
          std.reporter.error({
            from = __module_name__,
            subject = "fileformat_local",
            message = "File is modified without save, please save it first.",
            details = { winnr_command = winnr_command, bufnr = bufnr, filename = filename },
          })
          return
        end

        local cwd_name = std.path.basename(std.path.cwd()) ---@type string
        local offset_right = #cwd_name + 4 ---@type integer
        local fileformat_cur = vim.bo[bufnr].fileformat ---@type string

        ---@param callback              fun(widget: eve.ux.ISelectPopup, fileformat_next: string|nil): nil
        ---@return nil
        local function select_fileformat(callback)
          eve.ux.SelectPopup
            .new({
              wincfg = {
                relative = "editor",
                anchor = "SE",
                width = 12,
                row = vim.o.lines - 1,
                col = vim.o.columns - offset_right,
              },
              items = {
                { uuid = "dos", text = "dos" },
                { uuid = "mac", text = "mac" },
                { uuid = "unix", text = "unix" },
              },
              item_present_uuid = fileformat_cur,
              on_select = function(widget, item)
                if item ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
                  callback(widget, item.uuid)
                else
                  callback(widget, nil)
                end
              end,
            })
            :focus()
        end

        if vim.bo[bufnr].buftype == "nowrite" or vim.bo[bufnr].readonly then
          select_fileformat(function(widget, fileformat_next)
            if fileformat_next ~= nil then
              vim.bo[bufnr].fileformat = fileformat_next ---@type string
              widget:destroy()
            end
          end)
        else
          select_fileformat(function(widget, fileformat_next)
            if fileformat_next ~= nil then
              local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
              vim.bo[bufnr].fileformat = fileformat_next ---@type string
              widget:destroy()

              for i, line in ipairs(lines) do
                lines[i] = line:gsub("\r$", "")
              end
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines) ---@type string[]
            end
          end)
        end
      end,
    },
    hipatterns = {
      title = "hipatterns",
      snapshot = function()
        return "unknown", "Boolean"
      end,
      action = function()
        local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
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
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          eve.tab.focus_win_fixed(tabnr)
          eve.context.plugin.render_markdown:next(true)
          render_markdown.buf_toggle()
        end
      end,
    },
    relativenumber = {
      title = "relativenumber",
      snapshot = function()
        local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "Boolean"
        end

        local flag = vim.wo[winnr_command].relativenumber ---@type boolean
        return flag and "true" or "false", "Boolean"
      end,
      action = function()
        local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
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
        local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "Boolean"
        end

        local flag = vim.wo[winnr_command].wrap ---@type boolean
        return flag and "true" or "false", "Boolean"
      end,
      action = function()
        local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
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
        local host = eve.context.lsp.python_debug_host:snapshot() ---@type string
        if host == nil then
          return "nil", "Keyword"
        end
        return host, "String"
      end,
      action = function()
        local default_host = eve.context.lsp.python_debug_host:snapshot() or "" ---@type string
        local input_host = vim.fn.input("host [" .. default_host .. "]", default_host)
        local host = #input_host > 0 and input_host or default_host ---@type string
        eve.context.lsp.python_debug_host:next(host)
      end,
    },
    python_debug_port = {
      title = "python debug port",
      snapshot = function()
        local port = eve.context.lsp.python_debug_port:snapshot() ---@type integer
        if port == nil then
          return "nil", "Keyword"
        end
        return tostring(port), "Number"
      end,
      action = function()
        local default_port = eve.context.lsp.python_debug_port:snapshot() or 0 ---@type integer
        local input_port = vim.fn.input("port [" .. tostring(default_port) .. "]", tostring(default_port))
        local port = #input_port > 0 and tonumber(input_port) or default_port ---@type integer
        eve.context.lsp.python_debug_port:next(port)
      end,
    },
    python_venv = {
      title = "python venv path",
      snapshot = function()
        local venv_path = eve.context.lsp.python_venv_path:snapshot() ---@type string
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
  ux = {
    theme = {
      title = "theme",
      snapshot = function()
        local theme = eve.context.theme.theme:snapshot() ---@type std.e.Theme
        return theme, "String"
      end,
      action = function()
        eve.command.execute(eve.command.definitions.toggle.theme.uuid)
      end,
    },
    theme_variant = {
      title = "theme variant",
      snapshot = function()
        local theme = eve.context.theme.theme:snapshot() ---@type std.e.Theme
        local scheme = eve.context.theme.get_scheme(theme) ---@type std.t.theme.IScheme|nil
        return scheme and scheme.variant or "", "String"
      end,
      action = function()
        local theme = eve.context.theme.theme:snapshot() ---@type std.e.Theme
        local app_home = std.path.locate_app_config_home("guanghechen")
        local script_path = std.path.join(app_home, "config/theme/toggle_theme.mjs")
        local ok, error = pcall(function()
          vim.fn.system({ "node", script_path, theme })
        end)
        if not ok then
          std.reporter.error({
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
    local group = g ~= "misc" and g or nil ---@type string|nil
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
    elseif string.sub(g, 1, 1) == "_" then
      group = string.sub(g, 2)
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

    local px = group_priorities[vx.group] or 1000000 ---@type integer
    local py = group_priorities[vy.group] or 1000000 ---@type integer
    return px == py and vx.title < vy.title or px < py
  end)
end

---@return eve.ux.picker.composer.list.IResetData
local function fetch_data()
  local items = {} ---@type fml.action.toggle.IListItem[]

  for _, flag in ipairs(toggle_item_names) do
    local item = toggle_item_map[flag] ---@type fml.action.toggle.IItem
    local text_group = item.group or "" ---@type string
    local text_flag, hln_flag = item.snapshot()

    local w_p_title = 24 ---@type integer
    local w_p_group = 12 ---@type integer
    local offset = w_p_title + w_p_group + 2 ---@type integer

    ---@type string
    local text = string.format(
      "%s %s %s",
      std.string.pad_end(text_group, w_p_group, " "),
      std.string.pad_end(item.title, w_p_title, " "),
      text_flag
    )

    ---@type std.t.IHighlightInline[]
    local highlights = {
      { coll = 0, colr = #text_group + 1, hlname = "Special" },
      { coll = offset, colr = offset + #text_flag, hlname = hln_flag },
    }

    ---@type fml.action.toggle.IListItem
    local list_item = {
      uuid = flag,
      text = text,
      text_lower = text:lower(),
      highlights = highlights,
      data = item,
    }
    items[#items + 1] = list_item
  end

  ---@type eve.ux.picker.composer.list.IResetData
  return { items = items }
end

---@param picker                        eve.ux.picker.ListComposer
---@return nil
local function execute_action(picker)
  local lnum_current = picker.result.lnum_current:snapshot() ---@type integer
  if lnum_current >= 1 then
    local item = picker:retrieve(lnum_current) ---@type eve.ux.picker.composer.list.IItem|nil
    if item then
      ---@cast item fml.action.toggle.IListItem
      item.data.action()
      local data = fetch_data()
      picker:reset_data(data)
    end
  end
end

---@param _                              eve.ux.picker.ListComposer
---@param bufnr                          integer
---@param itemmap                        table<string, fml.action.toggle.IListItem>
---@param matches                        std.t.IScoredMatch[]
---@return eve.ux.picker.composer.list.IResultRenderData
local function result_render(_, bufnr, itemmap, matches)
  local lines = {} ---@type string[]
  local uuids = {} ---@type string[]

  for _, match in ipairs(matches) do
    local item = itemmap[match.uuid] ---@type fml.action.toggle.IListItem
    lines[#lines + 1] = item.text
    uuids[#uuids + 1] = item.uuid
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local nsnr_content = eve.var.nsnr.picker_result ---@type integer
  local nsnr_matches = eve.var.nsnr.picker_matches ---@type integer

  for lnum, match in ipairs(matches) do
    local row = lnum - 1 ---@type integer
    local item = itemmap[match.uuid] ---@type fml.action.toggle.IListItem

    if item and item.highlights then
      for _, hl in ipairs(item.highlights) do
        vim.hl.range(bufnr, nsnr_content, hl.hlname, { row, hl.coll }, { row, hl.colr }, { priority = 10 })
      end
    end

    if match.matches then
      for _, m in ipairs(match.matches) do
        vim.hl.range(bufnr, nsnr_matches, "f_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
      end
    end
  end

  ---@type eve.ux.picker.composer.list.IResultRenderData
  return { uuids = uuids }
end

eve.command.define({
  uuid = eve.command.definitions.toggle.list.uuid,
  desc = eve.command.definitions.toggle.list.desc,
  nargs = "?",
  candidates = toggle_item_names,
}, true)

---@class fml.action.toggle.list
local M = {}

local initialized = false ---@type boolean
local finder_input = std.Observable.from_value("") ---@type std.collection.IObservable
local flag_fuzzy = std.Observable.from_value(true) ---@type std.collection.IObservable
local flag_regex = std.Observable.from_value(false) ---@type std.collection.IObservable
local flag_sensitive = std.Observable.from_value(false) ---@type std.collection.IObservable

local picker ---@type eve.ux.picker.ListComposer
picker = eve.ux.picker.ListComposer.new({
  name = __module_name__,
  permanent = true,
  title = "Toggle Select",
  height = math.max(math.floor(vim.o.lines * 0.6), 24),
  width = 64,

  finder_input = finder_input,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,

  result_render = result_render,

  keymaps_finder = {
    {
      modes = { "i", "n", "v" },
      key = "<Tab>",
      desc = "toggle: execute action",
      callback = function()
        execute_action(picker)
      end,
    },
  },

  keymaps_result = {
    {
      modes = { "i", "n", "v" },
      key = "<Tab>",
      aliases = { "l", "h", "<Left>", "<Right>" },
      desc = "toggle: execute action",
      callback = function()
        execute_action(picker)
      end,
    },
  },

  on_confirm = function(composer, item)
    if item == nil then
      return
    end

    ---@cast item fml.action.toggle.IListItem
    composer:close()
    item.data.action()
  end,

  on_refresh = function(composer)
    local data = fetch_data()
    composer:reset_data(data)
  end,
})

---@param arg                           string|nil
---@return nil
function M.list(arg)
  local flag_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if toggle_item_map[flag_name] ~= nil then
    local item = toggle_item_map[flag_name] ---@type fml.action.toggle.IItem
    item.action()
  else
    if not initialized then
      initialized = true
      local data = fetch_data()
      picker:reset_data(data)
    end

    if flag_name ~= "" then
      finder_input:next(flag_name)
    end

    picker:focus()
  end
end

return M
