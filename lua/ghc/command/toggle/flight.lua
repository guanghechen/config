local __module_name__ = "ghc.command.toggle.flight" ---@type string

local reporter = require("eve.lib.reporter")
local Observable = require("eve.lib.collection.observable")
local state = require("eve.state")

local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

---@type string[]
local flights = {
  "autoload",
  "autosave",
  "copilot",
  "devmode",
  "lsp_inlay_hints",
}

---@param flight                        string
---@return nil
local function toggle_flight(flight)
  local observable = state.state.flight[flight] ---@type eve.lib.collection.IObservable|nil
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

eve.commander.register({
  uuid = uuids.toggle_flight,
  desc = "flight: toggle",
  candidates = flights,
  nargs = "?",
  action = function(args)
    local arg = type(args) == "string" and args:lower() or "" ---@type string
    if vim.tbl_contains(flights, arg) then
      toggle_flight(arg)
    else
      fml.fn.select({
        title = "Toggle flight",
        flag_fuzzy = true,
        flag_regex = false,
        input = Observable.from_value(arg),
        dimension = {
          row = 5,
          width = 50,
        },
        fetch_items = function()
          local items = {} ---@type fml.t.ux.select.IItem[]
          for _, flight in ipairs(flights) do
            table.insert(items, { uuid = flight, text = flight })
          end
          return items
        end,
        render_item = function(item, match)
          local flight = item.uuid ---@type string
          local observable = state.state.flight[flight] ---@type eve.lib.collection.IObservable
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
            ---@type eve.t.IHighlightInline[]
            local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
            table.insert(highlights, highlight)
          end
          return text, highlights
        end,
        on_confirm = function(item)
          local flight = item.uuid ---@type string
          toggle_flight(flight)
        end,
      })
    end
  end,
})
