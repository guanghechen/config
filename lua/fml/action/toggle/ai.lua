local ai_providers = eve.command.definitions.toggle.ai_provider.candidates ---@type string[]

---@class fml.action.toggle.ai
local M = {}

---@param arg                           string|nil
---@return nil
function M.ai_provider(arg)
  local ai_provider = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.list_contains(ai_providers, ai_provider) then
    eve.context.flight.ai_provider:next(ai_provider)
  else
    eve.ux.fn.select({
      title = "Toggle ai provider",
      flag_fuzzy = true,
      flag_regex = false,
      input = std.Observable.from_value(ai_provider),
      dimension = {
        row = 5,
        width = 50,
      },
      multiple = false,
      get_present = function()
        return eve.context.flight.ai_provider:snapshot() ---@type std.e.AiProvider
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
        local highlights = { { coll = 0, colr = -1, hlname = "String" } } ---@type std.t.IHighlightInline[]
        for _, piece in ipairs(match.matches) do
          highlights[#highlights + 1] = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
        end
        return text, highlights
      end,
      on_confirm = function(widget, items)
        if #items == 1 then
          local item = items[1] ---@type eve.ux.select.IItem
          widget:close()
          eve.context.flight.ai_provider:next(item.uuid)
        end
      end,
    })
  end
end

return M
