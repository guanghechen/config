---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.toggle.list" ---@type string

---@class era.m.toggle.IItem
---@field public title                  string
---@field public group                  string|nil
---@field public snapshot               fun(): string, string
---@field public action                 fun(): nil

---@class era.m.toggle.IListItem : era.m.picker.composer.list.IItem
---@field public data                   era.m.toggle.IItem

---@type table<string, integer>
local group_priorities = {
  behavior = 1,
  ["local"] = 2,
  ux = 3,
  flight = 4,
  lsp = 5,
  plugin = 6,
}

---@type table<string, table<string, stl.c.Observable<boolean>>>
local group_flags = {
  ---behavior
  behavior = {
    auto_im = dot.context.behavior.auto_im,
    bufs_relative = dot.context.behavior.bufs_relative,
  },

  ---flight
  flight = {
    autoformat = dot.context.flight.autoformat,
    autoload = dot.context.flight.autoload,
    autosave = dot.context.flight.autosave,
    devmode = dot.context.flight.devmode,
    dressing_clipboard = dot.context.flight.dressing_clipboard,
    dressing_dim = dot.context.flight.dressing_dim,
    dressing_illuminate = dot.context.flight.dressing_illuminate,
    dressing_image = dot.context.flight.dressing_image,
    dressing_indent = dot.context.flight.dressing_indent,
    dressing_input = dot.context.flight.dressing_input,
    dressing_scroll = dot.context.flight.dressing_scroll,
    dressing_select = dot.context.flight.dressing_select,
    dressing_trailspace = dot.context.flight.dressing_trailspace,
    dressing_ui_attach = dot.context.flight.dressing_ui_attach,
    dressing_virtcolumn = dot.context.flight.dressing_virtcolumn,
    dressing_winsep = dot.context.flight.dressing_winsep,
    gitdiff_expand_all = dot.context.flight.gitdiff_expand_all,
  },

  ---lsp
  lsp = {
    code_lens = dot.context.lsp.code_lens,
    diagnostics_virt_lines = dot.context.lsp.diagnostics_virt_lines,
    inlay_hints = dot.context.lsp.inlay_hints,
    spellcheck = dot.context.lsp.spellcheck,
  },

  ---ux
  ux = {
    expandtab = dot.context.option.expandtab,
    notification_paused = dot.state.status.notification_paused,
    relativenumber = dot.context.option.relativenumber,
    username = dot.context.theme.username,
    transparency = dot.context.theme.transparency,
  },

  ---plugin
  plugin = {
    minimap = dot.context.plugin.minimap,
    render_markdown = dot.context.plugin.render_markdown,
    treesitter_context = dot.context.plugin.treesitter_context,
    which_key = dot.context.plugin.which_key,
  },
}

---@type table<string, table<string, era.m.toggle.IItem>>
local group_items = {
  flight = {},
  ["local"] = {
    fileencoding = {
      title = "fileencoding",
      snapshot = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "String"
        end
        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer|nil
        local encoding = vim.api.nvim_get_option_value("fileencoding", { buf = bufnr }) ---@type string
        return encoding, "String"
      end,
      action = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
        local filename = yoz.path.basename(vim.api.nvim_buf_get_name(bufnr)) ---@type string
        if buftype ~= "" and buftype ~= "nowrite" then
          stl.reporter.error({
            from = __module_name__,
            subject = "fileencoding_local",
            message = "Unsupported buftype",
            details = { winnr_command = winnr_command, bufnr = bufnr, buftype = buftype, filename = filename },
          })
          return
        end

        if vim.api.nvim_get_option_value("modified", { buf = bufnr }) then
          stl.reporter.error({
            from = __module_name__,
            subject = "fileencoding_local",
            message = "File is modified without save, please save it first.",
            details = { winnr_command = winnr_command, bufnr = bufnr, filename = filename },
          })
          return
        end

        local cwd_name = yoz.path.basename(dot.path.cwd()) ---@type string
        local offset_right = #cwd_name + 4 ---@type integer
        local fileencoding_cur = vim.api.nvim_get_option_value("fileencoding", { buf = bufnr }) ---@type string

        ---@return nil
        local function reopen()
          era.fn.select_encoding({
            present = fileencoding_cur,
            title = string.format("Reopen with encoding (%s)", filename),
            on_select = function(encoding)
              if encoding ~= nil then
                local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
                if vim.api.nvim_win_is_valid(winnr_command) then
                  vim.api.nvim_tabpage_set_win(tabnr, winnr_command)
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
          era.fn.select_encoding({
            present = fileencoding_cur,
            title = string.format("Resave with encoding (%s)", filename),
            on_select = function(encoding)
              if encoding ~= nil then
                local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
                if vim.api.nvim_win_is_valid(winnr_command) then
                  vim.api.nvim_tabpage_set_win(tabnr, winnr_command)
                end
                if vim.api.nvim_buf_is_valid(bufnr) then
                  vim.api.nvim_buf_call(bufnr, function()
                    vim.api.nvim_set_option_value("fileencoding", encoding, { buf = bufnr })
                    vim.cmd("write")
                  end)
                end
              end
            end,
          })
        end

        if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "nowrite" or vim.api.nvim_get_option_value("readonly", { buf = bufnr }) then
          reopen()
        else
          era.m.select.open({
            relative = "editor",
            row = vim.o.lines - 3,
            col = vim.o.columns - offset_right - 12,
            items = {
              { key = "1", text = "reopen" },
              { key = "2", text = "resave" },
            },
            on_choice = function(item)
              if item ~= nil then
                if item.key == "1" then
                  reopen()
                else
                  resave()
                end
              end
            end,
          })
        end
      end,
    },
    fileformat = {
      title = "fileformat",
      snapshot = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "String"
        end
        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer|nil
        local fileformat = vim.api.nvim_get_option_value("fileformat", { buf = bufnr }) ---@type string
        return fileformat, "String"
      end,
      action = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
        local filename = yoz.path.basename(vim.api.nvim_buf_get_name(bufnr)) ---@type string
        if buftype ~= "" and buftype ~= "nowrite" then
          stl.reporter.error({
            from = __module_name__,
            subject = "fileformat_local",
            message = "Unsupported buftype",
            details = { winnr_command = winnr_command, bufnr = bufnr, buftype = buftype, filename = filename },
          })
          return
        end

        if vim.api.nvim_get_option_value("modified", { buf = bufnr }) then
          stl.reporter.error({
            from = __module_name__,
            subject = "fileformat_local",
            message = "File is modified without save, please save it first.",
            details = { winnr_command = winnr_command, bufnr = bufnr, filename = filename },
          })
          return
        end

        local cwd_name = yoz.path.basename(dot.path.cwd()) ---@type string
        local offset_right = #cwd_name + 4 ---@type integer
        local fileformat_cur = vim.api.nvim_get_option_value("fileformat", { buf = bufnr }) ---@type string

        ---@param callback              fun(fileformat_next: string|nil): nil
        ---@return nil
        local function select_fileformat(callback)
          era.m.select.open({
            relative = "editor",
            row = vim.o.lines - 4,
            col = vim.o.columns - offset_right - 12,
            items = {
              { key = "1", text = "dos" },
              { key = "2", text = "mac" },
              { key = "3", text = "unix" },
            },
            default_key = fileformat_cur == "dos" and "1" or fileformat_cur == "mac" and "2" or "3",
            on_choice = function(item)
              if item ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
                ---@type string
                local ff = item.key == "1" and "dos" or item.key == "2" and "mac" or "unix"
                callback(ff)
              else
                callback(nil)
              end
            end,
          })
        end

        if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "nowrite" or vim.api.nvim_get_option_value("readonly", { buf = bufnr }) then
          select_fileformat(function(fileformat_next)
            if fileformat_next ~= nil then
              vim.api.nvim_set_option_value("fileformat", fileformat_next, { buf = bufnr })
            end
          end)
        else
          select_fileformat(function(fileformat_next)
            if fileformat_next ~= nil then
              local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
              vim.api.nvim_set_option_value("fileformat", fileformat_next, { buf = bufnr })

              for i, line in ipairs(lines) do
                lines[i] = line:gsub("\r$", "")
              end
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
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
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
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
        require("render-markdown").buf_toggle()
        -- render-markdown's per-buffer toggle has no observable; notify inline math to re-sync.
        vim.api.nvim_exec_autocmds("User", {
          pattern = "EraImageMathSync",
          data = { buf = vim.api.nvim_get_current_buf() },
        })
      end,
    },
    maximize = {
      title = "maximize",
      snapshot = function()
        return "", "String"
      end,
      action = function()
        dot.command.definitions.toggle.maximize:execute()
      end,
    },
    number = {
      title = "number",
      snapshot = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "Boolean"
        end

        local enabled = vim.api.nvim_get_option_value("number", { win = winnr_command }) ---@type boolean
        return tostring(enabled), "Boolean"
      end,
      action = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local flag = vim.api.nvim_get_option_value("number", { win = winnr_command }) ---@type boolean
        vim.api.nvim_set_option_value("number", not flag, { win = winnr_command, scope = "local" })
      end,
    },
    relativenumber = {
      title = "relativenumber",
      snapshot = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "Boolean"
        end

        local enabled = vim.api.nvim_get_option_value("relativenumber", { win = winnr_command }) ---@type boolean
        return tostring(enabled), "Boolean"
      end,
      action = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local flag = vim.api.nvim_get_option_value("relativenumber", { win = winnr_command }) ---@type boolean
        vim.api.nvim_set_option_value("relativenumber", not flag, { win = winnr_command, scope = "local" })
      end,
    },
    signcolumn = {
      title = "signcolumn",
      snapshot = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "Boolean"
        end

        local signcolumn = vim.api.nvim_get_option_value("signcolumn", { win = winnr_command }) ---@type string
        local enabled = signcolumn ~= "no"
        return tostring(enabled), "Boolean"
      end,
      action = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local signcolumn = vim.api.nvim_get_option_value("signcolumn", { win = winnr_command }) ---@type string
        if signcolumn == "no" then
          vim.api.nvim_set_option_value("signcolumn", "yes", { win = winnr_command, scope = "local" })
        else
          vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr_command, scope = "local" })
        end
      end,
    },
    wrap = {
      title = "wrap",
      snapshot = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return "unknown", "Boolean"
        end

        local enabled = vim.api.nvim_get_option_value("wrap", { win = winnr_command }) ---@type boolean
        return tostring(enabled), "Boolean"
      end,
      action = function()
        local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
        if winnr_command == nil then
          return
        end

        local flag = vim.api.nvim_get_option_value("wrap", { win = winnr_command }) ---@type boolean
        vim.api.nvim_set_option_value("wrap", not flag, { win = winnr_command, scope = "local" })
      end,
    },
  },
  lsp = {
    python_debug_host = {
      title = "python debug host",
      snapshot = function()
        local host = dot.context.lsp.python_debug_host:snapshot() ---@type string
        if host == nil then
          return "nil", "Keyword"
        end
        return host, "String"
      end,
      action = function()
        local default_host = dot.context.lsp.python_debug_host:snapshot() or "" ---@type string
        local input_host = vim.fn.input("host [" .. default_host .. "]", default_host)
        local host = #input_host > 0 and input_host or default_host ---@type string
        dot.context.lsp.python_debug_host:next(host)
      end,
    },
    python_debug_port = {
      title = "python debug port",
      snapshot = function()
        local port = dot.context.lsp.python_debug_port:snapshot() ---@type integer
        if port == nil then
          return "nil", "Keyword"
        end
        return tostring(port), "Number"
      end,
      action = function()
        local default_port = dot.context.lsp.python_debug_port:snapshot() or 0 ---@type integer
        local input_port = vim.fn.input("port [" .. tostring(default_port) .. "]", tostring(default_port))
        local port = #input_port > 0 and tonumber(input_port) or default_port ---@type integer
        dot.context.lsp.python_debug_port:next(port)
      end,
    },
    python_venv = {
      title = "python venv path",
      snapshot = function()
        local venv_path = dot.context.lsp.python_venv_path:snapshot() ---@type string
        if venv_path == nil then
          return "nil", "Keyword"
        end
        return venv_path, "String"
      end,
      action = function()
        dot.command.definitions.lsp.select_python_venv:execute()
      end,
    },
  },
  ux = {
    theme = {
      title = "theme",
      snapshot = function()
        local theme = dot.context.theme.theme:snapshot() ---@type dot.e.ThemeFullName
        return theme, "String"
      end,
      action = function()
        dot.command.definitions.toggle.theme:execute()
      end,
    },
    theme_variant = {
      title = "theme variant",
      snapshot = function()
        local theme = dot.context.theme.theme:snapshot() ---@type dot.e.ThemeFullName
        local scheme = dot.context.theme.get_scheme(theme) ---@type stl.t.theme.IScheme|nil
        return scheme and scheme.variant or "", "String"
      end,
      action = function()
        local theme = dot.context.theme.theme:snapshot() ---@type dot.e.ThemeFullName
        local scheme = dot.context.theme.get_scheme(theme) ---@type stl.t.theme.IScheme|nil
        if scheme == nil or scheme.opposite == nil then
          return
        end

        local next_theme = string.format("%s-%s", scheme.theme, scheme.opposite) ---@type dot.e.ThemeFullName
        dot.command.definitions.toggle.theme:execute(next_theme)
      end,
    },
  },
  misc = {},
}

local toggle_item_map = {} ---@type table<string, era.m.toggle.IItem>
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
    local vx = toggle_item_map[x] ---@type era.m.toggle.IItem
    local vy = toggle_item_map[y] ---@type era.m.toggle.IItem

    local px = group_priorities[vx.group] or 1000000 ---@type integer
    local py = group_priorities[vy.group] or 1000000 ---@type integer
    return px == py and vx.title < vy.title or px < py
  end)
end

local dirty_data = true ---@type boolean
local search_pattern = stl.c.Observable.from_value("") ---@type stl.c.Observable
local flag_fuzzy = stl.c.Observable.from_value(true) ---@type stl.c.Observable
local flag_regex = stl.c.Observable.from_value(false) ---@type stl.c.Observable
local flag_case_sensitive = stl.c.Observable.from_value(false) ---@type stl.c.Observable

---@return era.m.picker.composer.list.IResetData
local function fetch_data()
  dirty_data = false

  local items = {} ---@type era.m.toggle.IListItem[]

  for _, flag in ipairs(toggle_item_names) do
    local item = toggle_item_map[flag] ---@type era.m.toggle.IItem
    local text_group = item.group or "" ---@type string
    local text_flag, hln_flag = item.snapshot()

    local w_p_title = 24 ---@type integer
    local w_p_group = 12 ---@type integer
    local offset = w_p_title + w_p_group + 2 ---@type integer

    ---@type string
    local text = string.format(
      "%s %s %s",
      stl.string.pad_end(text_group, w_p_group, " "),
      stl.string.pad_end(item.title, w_p_title, " "),
      text_flag
    )

    ---@type stl.t.IHighlightInline[]
    local highlights = {
      { coll = 0, colr = #text_group + 1, hlname = "Special" },
      { coll = offset, colr = offset + #text_flag, hlname = hln_flag },
    }

    ---@type era.m.toggle.IListItem
    local list_item = {
      uuid = flag,
      text = text,
      text_lower = text:lower(),
      highlights = highlights,
      data = item,
    }
    items[#items + 1] = list_item
  end

  ---@type era.m.picker.composer.list.IResetData
  return { items = items }
end

---@param picker                        era.m.picker.ListComposer
---@return nil
local function execute_action(picker)
  local lnum_current = picker.result.lnum_current:snapshot() ---@type integer
  if lnum_current >= 1 then
    local item = picker:retrieve(lnum_current) ---@type era.m.picker.composer.list.IItem|nil
    if item then
      ---@cast item era.m.toggle.IListItem
      item.data.action()
      local data = fetch_data()
      picker:reset_data(data)
    end
  end
end

---@type era.m.picker.composer.list.IRenderResult
local function render_result(_, bufnr, itemmap, matches)
  local lines = {} ---@type string[]
  local uuids = {} ---@type string[]

  for _, match in ipairs(matches) do
    local item = itemmap[match.uuid] ---@type era.m.picker.composer.list.IItem
    ---@cast item                       era.m.toggle.IListItem

    lines[#lines + 1] = item.text
    uuids[#uuids + 1] = item.uuid
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local nsnr_content = dot.var.nsnr.picker_result ---@type integer
  local nsnr_matches = dot.var.nsnr.picker_matches ---@type integer

  for lnum, match in ipairs(matches) do
    local item = itemmap[match.uuid] ---@type era.m.picker.composer.list.IItem
    ---@cast item                       era.m.toggle.IListItem

    local row = lnum - 1 ---@type integer
    if item and item.highlights then
      for _, hl in ipairs(item.highlights) do
        vim.hl.range(bufnr, nsnr_content, hl.hlname, { row, hl.coll }, { row, hl.colr }, { priority = 10 })
      end
    end

    if match.matches then
      for _, m in ipairs(match.matches) do
        vim.hl.range(bufnr, nsnr_matches, "m_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
      end
    end
  end

  ---@type era.m.picker.composer.list.IRenderResultData
  return { uuids = uuids }
end

dot.command.define({
  uuid = dot.command.definitions.toggle.list.uuid,
  desc = dot.command.definitions.toggle.list.desc,
  nargs = "?",
  candidates = toggle_item_names,
}, true)

---@class era.m.toggle.list
local M = {}

local picker ---@type era.m.picker.ListComposer
picker = era.m.picker.ListComposer.new({
  name = __module_name__,
  permanent = true,
  title = "Toggle Select",
  height = math.max(math.floor(vim.o.lines * 0.6), 24),
  width = 64,

  search_pattern = search_pattern,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_case_sensitive = flag_case_sensitive,

  render_result = render_result,

  keymaps_common = {
    {
      modes = { "i", "n", "x" },
      key = "<C-l>",
      desc = "toggle: execute action",
      callback = function()
        execute_action(picker)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-h>",
      desc = "toggle: execute action",
      callback = function()
        execute_action(picker)
      end,
    },
  },

  keymaps_finder = {
    {
      modes = { "i", "n", "x" },
      key = "<Tab>",
      desc = "toggle: execute action",
      callback = function()
        execute_action(picker)
      end,
    },
  },

  keymaps_result = {
    {
      modes = { "i", "n", "x" },
      key = "<Tab>",
      aliases = { "l", "h", "<Left>", "<Right>" },
      desc = "toggle: execute action",
      callback = function()
        execute_action(picker)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<space>",
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

    ---@cast item era.m.toggle.IListItem
    composer:close()

    dirty_data = true
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
    local item = toggle_item_map[flag_name] ---@type era.m.toggle.IItem
    item.action()
  else
    if dirty_data then
      local data = fetch_data()
      picker:reset_data(data)
    end

    if flag_name ~= "" then
      search_pattern:next(flag_name)
    end

    picker:focus()
  end
end

return M
