local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

---@class guanghechen.command.toggle.IItem
---@field public uuid                   string
---@field public title                  string
---@field public snapshot               fun(): string, string

---@type table<string, guanghechen.command.toggle.IItem>
local flag_map = {
  flight = {
    uuid = uuids.toggle_flight,
    title = "flight",
    snapshot = function()
      return "", "String"
    end,
  },
  relativenumber = {
    uuid = uuids.toggle_relativenumber,
    title = "relativenumber",
    snapshot = function()
      local observable = eve.context.state.theme.relativenumber ---@type t.eve.collection.IObservable
      local flag = observable:snapshot()
      return flag and "true" or "false", "Boolean"
    end,
  },
  theme = {
    uuid = uuids.toggle_theme,
    title = "theme",
    snapshot = function()
      local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
      local mode = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
      return theme .. "_" .. mode, "String"
    end,
  },
  theme_mode = {
    uuid = uuids.toggle_theme_mode,
    title = "theme mode",
    snapshot = function()
      local mode = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
      return mode, "String"
    end,
  },
  theme_transparency = {
    uuid = uuids.toggle_theme_transparency,
    title = "theme transparency",
    snapshot = function()
      local observable = eve.context.state.theme.transparency ---@type t.eve.collection.IObservable
      local flag = observable:snapshot()
      return flag and "true" or "false", "Boolean"
    end,
  },
  wrap = {
    uuid = uuids.toggle_wrap,
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

eve.commander.register({
  uuid = uuids.toggle,
  desc = "toggle",
  candidates = flags,
  nargs = "?",
  action = function(args)
    local arg = type(args) == "string" and args:lower() or "" ---@type string
    if flag_map[arg] ~= nil then
      local flag_item = flag_map[arg] ---@type guanghechen.command.toggle.IItem
      eve.commander.execute(flag_item.uuid)
    else
      fml.fn.select({
        title = "Toggle Select",
        flag_fuzzy = true,
        flag_regex = false,
        input = eve.c.Observable.from_value(arg),
        dimension = {
          row = 5,
          width = 50,
        },
        fetch_items = function()
          local items = {} ---@type t.fml.ux.select.IItem[]
          for _, flag in ipairs(flags) do
            local flag_item = flag_map[flag] ---@type guanghechen.command.toggle.IItem
            table.insert(items, { uuid = flag_item.uuid, text = flag })
          end
          return items
        end,
        render_item = function(item, match)
          local flag_item = flag_map[item.text] ---@type guanghechen.command.toggle.IItem
          local text_flag, hln_flag = flag_item.snapshot()

          local width_padding = 32 ---@type integer
          local padding = string.rep(" ", width_padding - vim.api.nvim_strwidth(item.text)) ---@type string
          local text = item.text .. padding .. text_flag ---@type string

          ---@type t.eve.IHighlightInline[]
          local highlights = {
            { coll = width_padding, colr = width_padding + #text_flag, hlname = hln_flag },
          }

          for _, piece in ipairs(match.matches) do
            ---@type t.eve.IHighlightInline[]
            local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
            table.insert(highlights, highlight)
          end
          return text, highlights
        end,
        on_confirm = function(item)
          eve.commander.execute(item.uuid)
        end,
      })
    end
  end,
})
